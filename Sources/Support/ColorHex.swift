import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    /// 略柔化的主文本色：比系统 `.primary` 更耐看（对比略低、不那么死黑 / 死白）。
    /// 作为根级默认前景色注入后，`.secondary` / `.tertiary` 会自动派生出柔和层级。
    static let appLabel: Color = {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return dark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.20, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.20, alpha: 1)
        })
        #endif
    }()

    /// 统一的「淡背景」token：卡片 / 周末格子 / 分区等次级表面的浅色填充。
    static let appFill: Color = {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return dark ? NSColor(white: 1, alpha: 0.05) : NSColor(white: 0, alpha: 0.035)
        })
        #else
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.05) : UIColor(white: 0, alpha: 0.035)
        })
        #endif
    }()

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
    static let hexes = ["#1E88E5", "#E53935", "#43A047", "#FB8C00",
                        "#8E24AA", "#00897B", "#F4511E", "#3949AB"]
}
