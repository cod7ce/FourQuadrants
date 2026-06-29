import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 感知剪贴板：若出现像链接 / 工单号的内容，则解析出来供「添加到象限」提示使用。
enum ClipboardReader {

    /// 返回（解析结果, 新的 changeCount）。
    /// 仅当剪贴板内容相对 `lastChange` 有变化、且解析出链接或工单号时才返回非 nil。
    @MainActor
    static func candidate(since lastChange: Int) async -> (ParsedTaskInput, Int)? {
        #if os(macOS)
        let pb = NSPasteboard.general
        let change = pb.changeCount
        guard change != lastChange,
              let raw = pb.string(forType: .string),
              !raw.isEmpty else { return nil }
        return parsed(from: raw, change: change)
        #else
        let pb = UIPasteboard.general
        let change = pb.changeCount
        guard change != lastChange else { return nil }
        // 先检测「是否像网址」——此调用不会触发系统的「粘贴」横幅。
        let patterns = (try? await pb.detectedPatterns(for: [.probableWebURL])) ?? []
        guard patterns.contains(.probableWebURL),
              let raw = pb.string, !raw.isEmpty else { return nil }
        return parsed(from: raw, change: change)
        #endif
    }

    private static func parsed(from raw: String, change: Int) -> (ParsedTaskInput, Int)? {
        let result = TaskInputParser.parse(raw)
        guard !result.links.isEmpty || result.issueKey != nil else { return nil }
        return (result, change)
    }
}
