import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    /// 主文本色（取自当前主题；切主题时整树刷新以重新求值）。
    static var appLabel: Color { ThemeManager.current.label }

    /// 次级表面填充色（取自当前主题）。
    static var appFill: Color { ThemeManager.current.surfaceAlt }

    /// 面板/容器表面色（取自当前主题；默认=窗口底色，终端=半透深板）。
    static var appSurface: Color { ThemeManager.current.surface }

    /// 分隔线色（跨平台：macOS separatorColor / iOS separator）。
    static var appSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    /// 从 "#RRGGBB" 解析颜色。
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}

/// 预设标签配色。
enum TagPalette {
    /// 常用标签色（2×5 网格）。
    static let hexes = ["#1E88E5", "#E53935", "#43A047", "#FB8C00", "#8E24AA",
                        "#00897B", "#F4511E", "#3949AB", "#D81B60", "#8D6E63"]
}
