import SwiftUI

extension Color {
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
