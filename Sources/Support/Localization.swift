import Foundation

/// 可选语言。`system` 跟随系统，其余强制对应语言。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var titleKey: String.LocalizationValue {
        switch self {
        case .system:  return "settings.language.system"
        case .zhHans:  return "settings.language.zh"
        case .english: return "settings.language.en"
        }
    }
}

/// 当前语言配置的单一来源（读自 UserDefaults，可在设置页修改）。
enum LocalizationConfig {
    static let storageKey = "appLanguage"

    static var code: String {
        UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.zhHans.rawValue
    }

    /// 日期/数字格式化用的语言环境。
    static var locale: Locale {
        code == AppLanguage.system.rawValue ? .autoupdatingCurrent : Locale(identifier: code)
    }

    /// 字符串查表用的 bundle —— 非「跟随系统」时指向对应语言的 .lproj。
    /// 关键：`String(localized:locale:)` 的 locale 只管格式化，不能选语言表，必须用 bundle 强制。
    static var bundle: Bundle {
        guard code != AppLanguage.system.rawValue,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }
}

/// 统一的本地化解析：按所选语言从对应 .lproj 取文案，避免中英混排。
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: LocalizationConfig.bundle, locale: LocalizationConfig.locale)
}

extension Locale {
    /// 应用当前语言环境（动态，随设置变化）。日期等格式化用它。
    static var app: Locale { LocalizationConfig.locale }
}
