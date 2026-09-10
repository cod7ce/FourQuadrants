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

/// 放在某区域背景上，使拖拽该区域可移动整个承载窗口（含 sheet 弹窗）：
/// 既开启 isMovableByWindowBackground，又在 mouseDown 时主动发起窗口拖拽。
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isMovableByWindowBackground = true
        }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// 「界面模糊」档位（0…1）→ NSVisualEffectView 材质（从清透到厚磨砂）。
/// 材质之间以磨砂/明度差异为主；默认档（0.5）对应 underWindowBackground，即现状观感。
enum ChromeMaterial {
    static let ordered: [NSVisualEffectView.Material] =
        [.hudWindow, .popover, .menu, .underWindowBackground, .headerView, .sidebar, .windowBackground]

    static func material(_ level: Double) -> NSVisualEffectView.Material {
        let clamped = min(max(level, 0), 1)
        let idx = Int((clamped * Double(ordered.count - 1)).rounded())
        return ordered[min(max(idx, 0), ordered.count - 1)]
    }
}

/// 让侧栏那一列的系统 vibrancy 材质失活（窗口底已清空为透明），
/// 从而让窗口级背景（BackgroundLayer 的背景图）连续透过侧栏显示。
struct SidebarVibrancyStripper: NSViewRepresentable {
    /// 是否启用；关闭时把材质恢复为激活，回到系统默认侧栏观感。
    var active: Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        apply(from: v)
        return v
    }
    func updateNSView(_ v: NSView, context: Context) { apply(from: v) }

    private func apply(from view: NSView) {
        let active = self.active
        DispatchQueue.main.async {
            var node: NSView? = view
            while let cur = node {
                if let eff = cur as? NSVisualEffectView {
                    eff.state = active ? .inactive : .followsWindowActiveState
                    break
                }
                node = cur.superview
            }
        }
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
                // 标题栏下方加一条分隔线
                w.titlebarSeparatorStyle = .line
            }
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}
#endif
