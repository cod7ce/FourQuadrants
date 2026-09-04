import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

// MARK: - 背景图填充方式

enum BackgroundFill: String, CaseIterable, Identifiable {
    case fill   // 填满（裁切）
    case fit    // 适应（留边，材质背衬）
    case tile   // 平铺
    var id: String { rawValue }
    // 不能用插值拼 key（会被当成格式串查表失败），须用字面 key。
    var titleKey: String.LocalizationValue {
        switch self {
        case .fill: return "settings.bg.fill.fill"
        case .fit:  return "settings.bg.fill.fit"
        case .tile: return "settings.bg.fill.tile"
        }
    }
}

// MARK: - 持久化键与默认值（全局一张，独立于主题）

enum BackgroundConfig {
    static let fileKey    = "bgImageFile"   // App Support 内文件名，空=无图
    static let scrimKey   = "bgScrim"       // 暗化/遮罩强度 0…1
    static let blurKey    = "bgBlur"        // 高斯模糊 0…40pt
    static let fillKey    = "bgFill"        // fill/fit/tile
    static let opacityKey = "bgOpacity"     // 图片自身不透明度 0…1

    static let defaultScrim   = 0.35
    static let defaultBlur    = 0.0
    static let maxBlur        = 40.0
    static let defaultOpacity = 1.0
    static let defaultFill    = BackgroundFill.fill.rawValue
}

// MARK: - 文件落盘与加载

/// 背景图文件存放在 App Support 沙盒目录内（沙盒安全，不持有用户原文件引用）。
enum BackgroundStore {
    /// 存放目录：App Support/<bundleID>/Backgrounds，按需创建。
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "FourQuadrants"
        let dir = base.appendingPathComponent(bundle, isDirectory: true)
                      .appendingPathComponent("Backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for filename: String) -> URL? {
        filename.isEmpty ? nil : directory.appendingPathComponent(filename)
    }

    /// 把选中的图片数据落盘并返回新文件名（唯一名，便于触发重载）。
    static func save(_ data: Data, ext: String) -> String? {
        let e = ext.isEmpty ? "img" : ext
        let name = UUID().uuidString + "." + e
        let dest = directory.appendingPathComponent(name)
        do { try data.write(to: dest); return name }
        catch { return nil }
    }

    static func remove(_ filename: String) {
        guard let url = url(for: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 跨平台加载为 SwiftUI Image（一次解码）。
    static func image(for filename: String) -> Image? {
        guard let url = url(for: filename),
              let platform = PlatformImage(contentsOfFile: url.path) else { return nil }
        #if os(macOS)
        return Image(nsImage: platform)
        #else
        return Image(uiImage: platform)
        #endif
    }
}
