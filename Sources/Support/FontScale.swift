import SwiftUI

/// 全局字号档位 → 缩放比例。用 ⌘+ / ⌘- / ⌘0 调整。
enum FontScale {
    static let key = "fontSizeIndex"

    static let defaultIndex = 3
    static let minIndex = 0
    static let maxIndex = 8
    static let step: CGFloat = 0.1   // 每档 ±10%

    static func clamp(_ i: Int) -> Int { min(max(i, minIndex), maxIndex) }

    /// 档位对应的缩放比例（默认档 = 1.0）。
    static func scale(_ i: Int) -> CGFloat {
        1.0 + CGFloat(clamp(i) - defaultIndex) * step
    }
}
