import Foundation

struct ParsedTaskInput: Equatable {
    var issueKey: String?
    var title: String
    var links: [String]
    /// 命中的规则要自动打上的标签名（内置识别为 nil）。
    var tagName: String? = nil

    var isEmpty: Bool { issueKey == nil && title.isEmpty && links.isEmpty }
}

/// 将一段（可能多行）输入解析为 工单号 / 标题 / 链接。纯函数，可单元测试。
enum TaskInputParser {
    /// 形如 ABC-123 的工单号。
    static let issueKeyPattern = #"\b[A-Z][A-Z0-9]*-\d+\b"#

    static func parse(_ raw: String) -> ParsedTaskInput {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 用 NSDataDetector 提取所有链接，并从文本中移除（从后往前以保持范围有效）。
        var links: [String] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = text as NSString
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                if let url = m.url { links.append(url.absoluteString) }
            }
            var mutable = text as NSString
            for m in matches.reversed() {
                mutable = mutable.replacingCharacters(in: m.range, with: " ") as NSString
            }
            text = mutable as String
        }

        // 2) 提取位于开头的工单号（仅当出现在文本起始处）。
        var issueKey: String?
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: issueKeyPattern) {
            let ns = trimmed as NSString
            if let first = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
               first.range.location == 0 {
                issueKey = ns.substring(with: first.range)
                text = ns.replacingCharacters(in: first.range, with: " ")
            } else {
                text = trimmed
            }
        } else {
            text = trimmed
        }

        // 3) 标题 = 剩余文本，按行合并、折叠空白。
        let title = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedTaskInput(issueKey: issueKey, title: title, links: links)
    }
}
