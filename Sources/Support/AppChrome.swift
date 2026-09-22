import SwiftUI

/// app 级外观环境（主题、强调色、语言、字号/字体）。
/// 主窗口与「屏幕居中」的独立弹窗共用，保证两边观感一致。
struct AppChrome: ViewModifier {
    @AppStorage(FontScale.key) private var fontIndex = FontScale.defaultIndex
    @AppStorage(AppFontSetting.key) private var appFontName = ""
    @AppStorage(ThemeManager.key) private var themeIDRaw = ThemeID.system.rawValue

    private var theme: AppTheme { AppTheme.theme(for: ThemeID(rawValue: themeIDRaw) ?? .system) }

    func body(content: Content) -> some View {
        content
            .tint(theme.id == .system ? nil : theme.accent)                  // 主题强调色（默认沿用系统）
            .preferredColorScheme(theme.forcedDark ? .dark : nil)            // 终端强制深色，与系统解耦
            .environment(\.theme, theme)
            .foregroundStyle(Color.appLabel)                                 // 主文本色（跟随主题）
            .environment(\.locale, .app)
            .environment(\.fontScale, FontScale.scale(fontIndex))            // ⌘+ / ⌘- 调整字号
            .environment(\.appFontName, appFontName)                         // 全局字体（设置里选）
            .environment(\.font, AppFont.font(.body, scale: FontScale.scale(fontIndex),
                                              name: theme.usesCustomFont ? appFontName : "",
                                              design: theme.fontDesign))
    }
}

extension View {
    func appChrome() -> some View { modifier(AppChrome()) }
}
