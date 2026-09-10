import SwiftUI

/// 全局背景图层：桌面材质 → 背景图 → 暗化罩。
/// 无图时保持现状（材质 + 主题色罩，零行为变化）；有图时用可调 scrim 取代满幅不透明罩，
/// 让图透出，可读性交给 scrim 与各内容表面自身的底色。
struct BackgroundLayer: View {
    @Environment(\.theme) private var theme
    @AppStorage(BackgroundConfig.fileKey)    private var file = ""
    @AppStorage(BackgroundConfig.scrimKey)   private var scrim = BackgroundConfig.defaultScrim
    @AppStorage(BackgroundConfig.blurKey)    private var blur = BackgroundConfig.defaultBlur
    @AppStorage(BackgroundConfig.fillKey)    private var fillRaw = BackgroundConfig.defaultFill
    @AppStorage(BackgroundConfig.opacityKey) private var opacity = BackgroundConfig.defaultOpacity
    @AppStorage(UIChromeConfig.opacityKey)   private var uiOpacity = UIChromeConfig.defaultOpacity
    @AppStorage(UIChromeConfig.blurKey)      private var uiBlur = UIChromeConfig.defaultBlur

    @State private var image: Image?

    private var fill: BackgroundFill { BackgroundFill(rawValue: fillRaw) ?? .fill }
    private var hasImage: Bool { !file.isEmpty && image != nil }

    var body: some View {
        ZStack {
            base
            if let image, hasImage {
                imageLayer(image)
                Color.black.opacity(scrim)          // 暗化罩：保证卡片/文字对比
            }
        }
        .ignoresSafeArea()
        .task(id: file) { image = BackgroundStore.image(for: file) }
    }

    /// 底层：无图时复刻现有窗口底（终端=材质叠半透近黑；默认玻璃=材质叠窗口色）；
    /// 有图时只留材质做背衬（图不满幅/半透时透出），不铺满幅不透明罩以免遮住图。
    @ViewBuilder private var base: some View {
        #if os(macOS)
        if file.isEmpty {
            // 模糊材质档位由 uiBlur 决定；染色层用主题基色 + 全局 uiOpacity（越低越透）
            VisualEffectView(material: ChromeMaterial.material(uiBlur))
                .overlay(theme.chromeBaseTint.opacity(uiOpacity))
        } else {
            VisualEffectView(material: ChromeMaterial.material(uiBlur))
        }
        #else
        if file.isEmpty {
            theme.background
        } else {
            Color.black
        }
        #endif
    }

    @ViewBuilder private func imageLayer(_ image: Image) -> some View {
        Group {
            switch fill {
            case .fill: image.resizable().scaledToFill()
            case .fit:  image.resizable().scaledToFit()
            case .tile: image.resizable(resizingMode: .tile)
            }
        }
        .blur(radius: blur)
        .opacity(opacity)
        .clipped()
    }
}
