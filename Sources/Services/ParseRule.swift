import Foundation

/// 用户自定义的粘贴解析规则：用一条正则，并指定捕获组分别对应 编号 / 标题 / 链接。
struct ParseRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = ""
    var pattern: String = ""
    var issueGroup: Int = 0   // 0 表示无
    var titleGroup: Int = 0
    var linkGroup: Int = 0
    /// 命中该规则时，自动给生成的任务打上这个标签（空 = 不打）。
    var tagName: String = ""
}

/// 规则持久化（存于 UserDefaults）。
enum ParseRuleStore {
    static let key = "parseRules"
    /// 内置「智能识别（默认）」规则的自动标签存储键。
    static let builtinTagKey = "builtinParseTagName"

    static func load() -> [ParseRule] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([ParseRule].self, from: data) else {
            return []
        }
        return rules
    }

    static func save(_ rules: [ParseRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// 解析引擎：先按顺序尝试用户正则规则，首个匹配生效；否则回退到内置智能识别（默认）。
enum ParseEngine {
    static func parse(_ text: String) -> ParsedTaskInput {
        for rule in ParseRuleStore.load() {
            if let result = apply(rule, to: text), !result.isEmpty {
                return result
            }
        }
        // 回退到内置识别，套用内置规则的自动标签（如已配置）。
        var result = TaskInputParser.parse(text)
        let builtinTag = (UserDefaults.standard.string(forKey: ParseRuleStore.builtinTagKey) ?? "")
            .trimmingCharacters(in: .whitespaces)
        if result.tagName == nil, !builtinTag.isEmpty { result.tagName = builtinTag }
        return result
    }

    static func apply(_ rule: ParseRule, to text: String) -> ParsedTaskInput? {
        guard !rule.pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: rule.pattern,
                                                   options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        func group(_ i: Int) -> String? {
            guard i > 0, i < match.numberOfRanges else { return nil }
            let r = match.range(at: i)
            guard r.location != NSNotFound else { return nil }
            return ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let issue = group(rule.issueGroup)
        let title = group(rule.titleGroup) ?? ""
        let link = group(rule.linkGroup)
        return ParsedTaskInput(issueKey: issue,
                               title: title,
                               links: link.map { [$0] } ?? [],
                               tagName: rule.tagName.isEmpty ? nil : rule.tagName)
    }
}
