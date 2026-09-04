import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 感知剪贴板：若出现像链接 / 工单号的内容，则解析出来供「添加到象限」提示使用。
enum ClipboardReader {

    /// 返回（解析结果, 新的 changeCount）。
    /// 仅当剪贴板内容相对 `lastChange` 有变化、且解析出「工单号」时才返回非 nil。
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
        // iOS 用 keypath 形式的检测模式（\DetectedValues.probableWebURL）。
        let webURL: PartialKeyPath<UIPasteboard.DetectedValues> = \.probableWebURL
        let patterns = (try? await pb.detectedPatterns(for: [webURL])) ?? []
        guard patterns.contains(webURL),
              let raw = pb.string, !raw.isEmpty else { return nil }
        return parsed(from: raw, change: change)
        #endif
    }

    private static func parsed(from raw: String, change: Int) -> (ParsedTaskInput, Int)? {
        let result = ParseEngine.parse(raw)
        // 仅当解析出「工单号」时才提示，避免任意链接都触发。
        guard result.issueKey != nil else { return nil }
        return (result, change)
    }
}
