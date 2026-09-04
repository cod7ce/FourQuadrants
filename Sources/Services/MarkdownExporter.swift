import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#else
import UIKit
#endif

/// 把某一周的任务导出为 Markdown：按标签分组，子任务缩进跟随父任务。
enum MarkdownExporter {

    /// 生成 Markdown 文本。`weekTasks` 为该周任务（可含子任务，内部只取顶层）。
    static func markdown(weekStart: Date, weekTasks: [TaskItem]) -> String {
        let top = weekTasks.topLevel

        var out = "# \(L("export.md.title"))\n"

        // 按标签分组：一个任务若有多个标签，会出现在每个标签下；无标签归到「未分类」。
        var groups: [(name: String, tasks: [TaskItem])] = []
        let tagNames = Set(top.flatMap { $0.tagList.map(\.name) }).sorted()
        for name in tagNames {
            let items = top.filter { $0.tagList.contains { $0.name == name } }
            if !items.isEmpty { groups.append((name, items)) }
        }
        let untagged = top.filter { $0.tagList.isEmpty }
        if !untagged.isEmpty { groups.append((L("export.md.untagged"), untagged)) }

        for g in groups {
            out += "\n## \(g.name)\n\n"
            for t in g.tasks { out += lines(for: t, indent: 0) }
        }
        return out
    }

    /// 单个任务（含其子任务）的 Markdown 行：普通无序列表；有链接则在标题后附 `[↗](url)`。
    private static func lines(for t: TaskItem, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        var title = t.title.isEmpty ? L("task.default.title") : t.title
        if let key = t.issueKey, !key.isEmpty { title = "\(key) \(title)" }
        if let url = t.urls.first { title += " [[↗](\(url.absoluteString))]" }
        var s = "\(pad)- \(title)\n"
        for sub in t.sortedSubtasks { s += lines(for: sub, indent: indent + 1) }
        return s
    }

    /// 复制到剪贴板（跨平台）。
    @MainActor
    static func copyToPasteboard(weekStart: Date, weekTasks: [TaskItem]) {
        let text = markdown(weekStart: weekStart, weekTasks: weekTasks)
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    #if os(macOS)
    /// 弹出保存面板，导出为 .md 文件。
    @MainActor
    static func exportToFile(weekStart: Date, weekTasks: [TaskItem]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "\(Week.yearWeekLabel(weekStart)).md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = markdown(weekStart: weekStart, weekTasks: weekTasks)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
    #endif
}
