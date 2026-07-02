#if os(macOS)
import SwiftUI
import AppKit

/// 系统「玻璃材质」背景（behind-window 混合，可透出并模糊桌面）。
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
    }
}

/// 让承载窗口变为非不透明 + 清空背景色，behind-window 材质才能透出桌面。
struct WindowTranslucency: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window {
                w.isOpaque = false
                w.backgroundColor = .clear
                // 标题栏透明，由同一层窗口材质透上来，避免与内容区出现分界
                w.titlebarAppearsTransparent = true
            }
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}
#endif
