import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - 主题标识

enum ThemeID: String, CaseIterable, Identifiable {
    case system     // 默认（跟随系统明暗，现状观感）
    case terminal   // 终端（深色 · 等宽 · 括号勾选 · #标签 · 树形子任务 · 状态栏）
    var id: String { rawValue }
    var titleKey: String.LocalizationValue { "theme.\(rawValue)" }
}

// MARK: - 组件皮肤枚举

enum ThemeCheckbox { case circle, bracket }
enum ThemeTag { case chip, hash }
enum ThemeSubtask { case indent, tree }
enum ThemeEmpty { case icon, comment }
enum ThemeCardStyle { case tinted, panel }     // tinted=象限色底；panel=中性底+左色条
enum ThemeChrome { case glass, solid }
enum ThemeFontDesign { case system, monospaced }

// MARK: - 主题

struct AppTheme {
    var id: ThemeID
    var forcedDark: Bool            // 是否强制深色 colorScheme
    // 颜色（覆盖品牌色；.secondary/.tertiary/材质靠 colorScheme 自适应）
    var background: Color
    var surface: Color
    var surfaceAlt: Color
    var label: Color
    var accent: Color
    var q1: Color; var q2: Color; var q3: Color; var q4: Color
    // 排版
    var fontDesign: ThemeFontDesign
    var usesCustomFont: Bool        // 是否套用「设置」里的自选字体（终端强制 mono，忽略）
    // 组件皮肤 / 外壳
    var checkbox: ThemeCheckbox
    var tag: ThemeTag
    var subtask: ThemeSubtask
    var emptyState: ThemeEmpty
    var cardStyle: ThemeCardStyle
    var chrome: ThemeChrome
    var showBreadcrumb: Bool
    var showStatusBar: Bool

    func quadrant(_ q: Quadrant) -> Color {
        switch q {
        case .urgentImportant: return q1
        case .important:       return q2
        case .urgent:          return q3
        case .neither:         return q4
        }
    }
}

// MARK: - 动态色 & 注册表

private func themeDynamic(_ light: Color, _ dark: Color) -> Color {
    #if os(macOS)
    return Color(nsColor: NSColor(name: nil) { ap in
        ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
    })
    #else
    return Color(uiColor: UIColor { tr in
        tr.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
    })
    #endif
}

extension AppTheme {
    /// 默认主题：沿用现状（跟随系统明暗的自适应色）。
    static let system = AppTheme(
        id: .system,
        forcedDark: false,
        background: Color(nsColor: .windowBackgroundColor),
        surface: Color(nsColor: .windowBackgroundColor),
        surfaceAlt: themeDynamic(Color(white: 0, opacity: 0.035), Color(white: 1, opacity: 0.05)),
        label: themeDynamic(Color(white: 0.20), Color(white: 0.92)),
        accent: Color.accentColor,
        q1: .red, q2: .blue, q3: .orange, q4: .secondary,
        fontDesign: .system, usesCustomFont: true,
        checkbox: .circle, tag: .chip, subtask: .indent, emptyState: .icon,
        cardStyle: .tinted, chrome: .glass, showBreadcrumb: false, showStatusBar: false
    )

    /// 终端主题：深色 · 等宽 · 方括号勾选 · #标签 · 树形子任务 · 面板+状态栏。
    static let terminal = AppTheme(
        id: .terminal,
        forcedDark: true,
        background: Color(red: 0.013, green: 0.011, blue: 0.026, opacity: 0.84), // 近黑·半透，桌面透出
        surface: Color(white: 1, opacity: 0.035),        // 面板：极淡白覆盖，衬出层次
        surfaceAlt: Color(white: 1, opacity: 0.065),      // 填充/收集箱盒
        label: Color(hex: "#E7E9F3") ?? .white,
        accent: Color(hex: "#3AD07D") ?? .green,
        q1: Color(hex: "#FF5C7A") ?? .red,
        q2: Color(hex: "#5B8CFF") ?? .blue,
        q3: Color(hex: "#FFB454") ?? .orange,
        q4: Color(hex: "#8A90B8") ?? .gray,
        fontDesign: .monospaced, usesCustomFont: false,
        checkbox: .bracket, tag: .hash, subtask: .tree, emptyState: .comment,
        cardStyle: .panel, chrome: .solid, showBreadcrumb: true, showStatusBar: true
    )

    static func theme(for id: ThemeID) -> AppTheme {
        switch id { case .system: return .system; case .terminal: return .terminal }
    }
}

/// 全局取当前主题（供非 View 上下文的语义色访问；切主题时整树刷新以重新求值）。
enum ThemeManager {
    static let key = "themeID"
    static var currentID: ThemeID {
        ThemeID(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }
    static var current: AppTheme { AppTheme.theme(for: currentID) }
}

// MARK: - 环境注入

private struct ThemeKey: EnvironmentKey { static let defaultValue: AppTheme = .system }
extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
