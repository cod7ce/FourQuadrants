import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 文字缩放比例环境值（由根视图按字号档位注入）。
private struct FontScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
/// 全局字体族名环境值（空 = 系统默认；由设置注入）。
private struct AppFontNameKey: EnvironmentKey { static let defaultValue: String = "" }

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
    var appFontName: String {
        get { self[AppFontNameKey.self] }
        set { self[AppFontNameKey.self] = newValue }
    }
}

/// 字体设置的存储键。
enum AppFontSetting {
    static let key = "appFontName"
}

enum AppFont {
    /// 文本样式在当前平台的基准点值。
    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        #if os(macOS)
        return NSFont.preferredFont(forTextStyle: nsStyle(style)).pointSize
        #else
        return UIFont.preferredFont(forTextStyle: uiStyle(style)).pointSize
        #endif
    }

    /// 文本样式的大写字母高度（用于图标与首行文字的视觉居中对齐）。
    static func capHeight(_ style: Font.TextStyle, scale: CGFloat) -> CGFloat {
        #if os(macOS)
        return NSFont.preferredFont(forTextStyle: nsStyle(style)).capHeight * scale
        #else
        return UIFont.preferredFont(forTextStyle: uiStyle(style)).capHeight * scale
        #endif
    }

    static func defaultWeight(_ style: Font.TextStyle) -> Font.Weight {
        switch style {
        case .headline: return .semibold
        default: return .regular
        }
    }

    /// 按比例缩放后的字体。`name` 非空时用自定义字体族，否则用系统字体。
    static func font(_ style: Font.TextStyle, scale: CGFloat,
                     weight: Font.Weight? = nil,
                     monospaced: Bool = false, monospacedDigit: Bool = false,
                     name: String = "") -> Font {
        let size = baseSize(style) * scale
        let w = weight ?? defaultWeight(style)
        var f: Font
        if name.isEmpty {
            f = Font.system(size: size, weight: w)
            if monospaced { f = f.monospaced() }
        } else {
            f = Font.custom(name, size: size).weight(w)
        }
        if monospacedDigit { f = f.monospacedDigit() }
        return f
    }

    #if os(macOS)
    static func nsStyle(_ s: Font.TextStyle) -> NSFont.TextStyle {
        switch s {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    #else
    static func uiStyle(_ s: Font.TextStyle) -> UIFont.TextStyle {
        switch s {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    #endif
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.fontScale) private var scale
    @Environment(\.appFontName) private var name
    let style: Font.TextStyle
    let weight: Font.Weight?
    let monospaced: Bool
    let monospacedDigit: Bool

    func body(content: Content) -> some View {
        content.font(AppFont.font(style, scale: scale, weight: weight,
                                  monospaced: monospaced, monospacedDigit: monospacedDigit,
                                  name: name))
    }
}

extension View {
    /// 按全局字号档位缩放的文字样式（在 macOS 上可靠生效）。
    func appFont(_ style: Font.TextStyle = .body,
                 weight: Font.Weight? = nil,
                 monospaced: Bool = false,
                 monospacedDigit: Bool = false) -> some View {
        modifier(AppFontModifier(style: style, weight: weight,
                                 monospaced: monospaced, monospacedDigit: monospacedDigit))
    }

    /// 在 `HStack(alignment: .firstTextBaseline)` 中，让图标与首行 body 文字视觉居中对齐。
    /// 用 ~0.42em（而非拉丁 capHeight 的一半）作为基线上方的视觉中心，更贴合中文字形。
    func alignedToFirstLine(scale: CGFloat) -> some View {
        alignmentGuide(.firstTextBaseline) { d in
            d[VerticalAlignment.center] + AppFont.baseSize(.body) * scale * 0.42
        }
    }
}
