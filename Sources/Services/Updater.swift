#if os(macOS)
import Foundation
import AppKit

/// 自动更新：匿名读 GitHub Releases（公开仓库），下载新版 zip，`ditto` 原地替换并重启。
/// 不用 Sparkle —— 那要求 Developer ID 签名；这里只有 Apple Development 证书，
/// 故仿照同作者 scratch 应用的做法：下载后去 quarantine，写一段 swap 脚本在本进程退出后换包。
@MainActor
final class Updater {
    static let shared = Updater()
    private init() {}

    private let repo = "cod7ce/FourQuadrants"
    private var apiURL: URL { URL(string: "https://api.github.com/repos/\(repo)/releases/latest")! }
    var releasesPage: URL { URL(string: "https://github.com/\(repo)/releases/latest")! }
    private let checkInterval: TimeInterval = 6 * 3600
    private let firstDelay: TimeInterval = 20

    private var busy = false
    private var started = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    struct Release {
        let version: String
        let notes: String
        let pageURL: URL
        let asset: Asset?
        struct Asset { let name: String; let url: URL; let size: Int }
    }

    // MARK: - 调度

    /// 启动后延迟首检 + 周期性后台静默检查。开发构建（DEBUG）不检查。
    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        return
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + firstDelay) { [weak self] in
            Task { await self?.checkForUpdates(silent: true) }
        }
        Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { await self?.checkForUpdates(silent: true) }
        }
        #endif
    }

    /// 检查更新。silent=true 时无更新/失败都不打扰（后台用）。
    func checkForUpdates(silent: Bool) async {
        if busy { return }
        let latest: Release
        do {
            latest = try await fetchLatest()
        } catch {
            if !silent {
                info(.warning, "检查更新失败", "没能连上 GitHub", (error as? Err)?.text ?? error.localizedDescription)
            }
            return
        }
        guard isNewer(latest.version, than: currentVersion) else {
            if !silent { info(.informational, "检查更新", "已经是最新版本", "当前版本 v\(currentVersion)") }
            return
        }
        promptInstall(latest)
    }

    // MARK: - 查询最新版

    private var machineArch: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    private func fetchLatest() async throws -> Release {
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("FourQuadrants/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Err("无响应") }
        if http.statusCode == 404 { throw Err("还没有发布过任何版本") }
        guard http.statusCode == 200 else { throw Err("GitHub 返回 \(http.statusCode)") }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if json["draft"] as? Bool == true { throw Err("最新的发布还是草稿") }
        let tag = json["tag_name"] as? String ?? ""
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let notes = json["body"] as? String ?? ""
        let page = (json["html_url"] as? String).flatMap { URL(string: $0) } ?? releasesPage

        let suffix = "-mac-\(machineArch).zip"
        var asset: Release.Asset?
        for a in json["assets"] as? [[String: Any]] ?? [] {
            let name = a["name"] as? String ?? ""
            if name.hasSuffix(suffix),
               let s = a["browser_download_url"] as? String, let url = URL(string: s) {
                asset = .init(name: name, url: url, size: a["size"] as? Int ?? 0)
                break
            }
        }
        return Release(version: version, notes: notes, pageURL: page, asset: asset)
    }

    // MARK: - 版本比较（semver，忽略预发布后缀）

    func isNewer(_ candidate: String, than current: String) -> Bool {
        func nums(_ v: String) -> [Int] {
            let core = v.split(separator: "-").first.map(String.init) ?? v
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = nums(candidate), b = nums(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - 提示 + 安装

    private func promptInstall(_ latest: Release) {
        let canAuto = latest.asset != nil
        let a = NSAlert()
        a.alertStyle = .informational
        a.messageText = "发现新版本 v\(latest.version)"
        let notes = latest.notes.isEmpty ? "包含一些改进。" : String(latest.notes.prefix(600))
        a.informativeText = "\(notes)\n\n当前版本 v\(currentVersion)"
        if canAuto { a.addButton(withTitle: "现在更新") }
        a.addButton(withTitle: "打开下载页")
        a.addButton(withTitle: "以后再说")

        let r = a.runModal()
        if canAuto && r == .alertFirstButtonReturn {
            Task { await downloadAndInstall(latest) }
        } else if (canAuto && r == .alertSecondButtonReturn) || (!canAuto && r == .alertFirstButtonReturn) {
            NSWorkspace.shared.open(latest.pageURL)
        }
    }

    private func downloadAndInstall(_ latest: Release) async {
        guard let asset = latest.asset else { return }
        busy = true
        defer { busy = false }
        let work = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("fourquadrants-update", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: work)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

            let (tmp, resp) = try await URLSession.shared.download(from: asset.url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw Err("下载失败") }
            let archive = work.appendingPathComponent(asset.name)
            try FileManager.default.moveItem(at: tmp, to: archive)

            try installMac(archive: archive, work: work)   // 成功则退出并重启，不会返回
        } catch {
            info(.critical, "更新失败", "更新没能完成",
                 "\((error as? Err)?.text ?? error.localizedDescription)\n\n可到发布页手动下载：\n\(releasesPage.absoluteString)")
        }
    }

    private func installMac(archive: URL, work: URL) throws {
        let extractDir = work.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, extractDir.path])

        let entries = (try? FileManager.default.contentsOfDirectory(atPath: extractDir.path)) ?? []
        guard let appName = entries.first(where: { $0.hasSuffix(".app") }) else {
            throw Err("安装包里没找到 .app")
        }
        let newApp = extractDir.appendingPathComponent(appName)
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

        let currentApp = Bundle.main.bundleURL   // …/FourQuadrants.app
        guard currentApp.pathExtension == "app" else { throw Err("当前不是 .app 形式，无法原地更新") }
        let parent = currentApp.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw Err("没有权限写入 \(parent.path)，请把 App 放到「应用程序」或个人目录下再更新")
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let script = work.appendingPathComponent("swap.sh")
        let body = """
        #!/bin/bash
        set -e
        PID=\(pid)
        for i in $(seq 1 100); do kill -0 "$PID" 2>/dev/null || break; sleep 0.2; done
        NEW=\(shq(newApp.path))
        CUR=\(shq(currentApp.path))
        BACKUP="$CUR.old-$$"
        mv "$CUR" "$BACKUP"
        if /usr/bin/ditto "$NEW" "$CUR"; then
          rm -rf "$BACKUP"
        else
          rm -rf "$CUR"; mv "$BACKUP" "$CUR"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$CUR" || true
        sleep 0.5
        /usr/bin/open "$CUR"
        rm -rf \(shq(work.path)) || true
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        // 分离启动 swap 脚本：新会话，脱离本进程，退出后由它换包并重启。
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "setsid bash \(shq(script.path)) >/dev/null 2>&1 &"]
        try task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
    }

    // MARK: - 小工具

    @discardableResult
    private func run(_ cmd: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if p.terminationStatus != 0 { throw Err("\(cmd) 失败：\(out)") }
        return out
    }

    /// shell 单引号转义。
    private func shq(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func info(_ style: NSAlert.Style, _ message: String, _ text: String, _ detail: String) {
        let a = NSAlert()
        a.alertStyle = style
        a.messageText = text
        a.informativeText = detail.isEmpty ? message : detail
        a.addButton(withTitle: "好的")
        a.runModal()
    }

    struct Err: LocalizedError {
        let text: String
        init(_ t: String) { text = t }
        var errorDescription: String? { text }
    }
}
#endif
