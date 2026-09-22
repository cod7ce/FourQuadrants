import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// 视图被放进独立窗口（而非 sheet）时，用它替代 `dismiss()` 关窗。
private struct CloseHostWindowKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var closeHostWindow: (() -> Void)? {
        get { self[CloseHostWindowKey.self] }
        set { self[CloseHostWindowKey.self] = newValue }
    }
}

extension View {
    /// 独立窗口弹窗：以 app 窗口为中心；那样会被屏幕边缘裁掉时，改在屏幕正中。
    /// （sheet 是贴着 app 窗口下沿展开的，窗口靠边就会被挤掉一截。）iOS 保持 sheet。
    func centeredWindow<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        #if os(macOS)
        modifier(CenteredWindowModifier(item: item, windowContent: content))
        #else
        sheet(item: item) { content($0) }
        #endif
    }

    /// 同上，Bool 触发版。
    func centeredWindow<C: View>(isPresented: Binding<Bool>,
                                 @ViewBuilder content: @escaping () -> C) -> some View {
        centeredWindow(item: Binding(get: { isPresented.wrappedValue ? PresentToken() : nil },
                                     set: { if $0 == nil { isPresented.wrappedValue = false } })) { _ in
            content()
        }
    }

    /// 任务编辑器弹窗（新建 / 查看既有任务）。
    func taskEditorWindow(item: Binding<TaskItem?>, isNew: Bool = false) -> some View {
        centeredWindow(item: item) { TaskEditor(task: $0, isNew: isNew) }
    }

    /// 同上，用于「双击某条任务查看/编辑」这种 Bool 触发的场景。
    func taskEditorWindow(isPresented: Binding<Bool>, task: TaskItem) -> some View {
        taskEditorWindow(item: Binding(get: { isPresented.wrappedValue ? task : nil },
                                       set: { if $0 == nil { isPresented.wrappedValue = false } }))
    }
}

/// `centeredWindow(isPresented:)` 的占位 item。
struct PresentToken: Identifiable {
    let id = 0
}

#if os(macOS)

private struct CenteredWindowModifier<Item: Identifiable, C: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder let windowContent: (Item) -> C
    @Environment(\.modelContext) private var context
    @StateObject private var host = CenteredWindowHost()

    func body(content: Content) -> some View {
        content.onChange(of: item?.id) { _, _ in
            if let value = item {
                host.present(container: context.container, onClose: { item = nil }) {
                    windowContent(value)
                }
            } else {
                host.dismiss()
            }
        }
    }
}

/// 承载弹窗内容的独立窗口：优先以发起它的 app 窗口为中心，放不下才退回屏幕正中；
/// 浮在 app 窗口之上，随 app 切走而隐藏。
@MainActor
private final class CenteredWindowHost: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?
    /// 关窗后再多留一轮 runloop，好让 SwiftUI 跑完 `.onDisappear`（保存/丢弃空任务）。
    private var retiring: NSHostingController<AnyView>?
    private var onClose: (() -> Void)?
    /// 发起这个弹窗的窗口（优先以它为中心）。
    private weak var anchor: NSWindow?

    func present<C: View>(container: ModelContainer,
                          onClose: @escaping () -> Void,
                          @ViewBuilder content: () -> C) {
        self.onClose = nil              // 连点时先收掉上一个，但别顺手把 binding 清空
        dismiss()
        self.onClose = onClose
        anchor = NSApp.keyWindow ?? NSApp.mainWindow

        let root = content()
            .modelContainer(container)
            .appChrome()
            .environment(\.closeHostWindow) { [weak self] in self?.dismiss() }
        let hosting = NSHostingController(rootView: AnyView(root))
        hosting.safeAreaRegions = []    // 内容自己铺满，不给隐藏的标题栏让出 32pt

        // styleMask 必须在建窗时给定，fullSizeContentView 才生效（否则会多出一条标题栏）
        let w = CenteredWindow(contentRect: .zero,
                               styleMask: [.titled, .closable, .fullSizeContentView],
                               backing: .buffered,
                               defer: false)
        w.contentViewController = hosting
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            w.standardWindowButton(button)?.isHidden = true   // 弹窗内容自带关闭按钮
        }
        w.isMovableByWindowBackground = true
        w.level = .floating
        w.hidesOnDeactivate = true
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.setContentSize(hosting.view.fittingSize)
        w.setFrameOrigin(origin(for: w))
        window = w

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() { window?.close() }   // 收尾统一在 windowWillClose

    /// 内容尺寸变化（窗口不可手动缩放）后重新摆位。
    func windowDidResize(_ notification: Notification) {
        guard let w = window else { return }
        w.setFrameOrigin(origin(for: w))
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = window else { return }
        if let hosting = w.contentViewController as? NSHostingController<AnyView> {
            retiring = hosting
            hosting.rootView = AnyView(EmptyView())   // 拆掉视图树，触发 .onDisappear
            DispatchQueue.main.async { [weak self] in self?.retiring = nil }
        }
        w.delegate = nil
        window = nil
        anchor = nil
        let close = onClose
        onClose = nil
        close?()
    }

    /// 摆位：以发起弹窗的 app 窗口为中心；这样会被屏幕边缘裁掉的话，改用屏幕正中。
    private func origin(for window: NSWindow) -> NSPoint {
        let screen = anchor?.screen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return window.frame.origin }
        return PopupPlacement.origin(size: window.frame.size, host: anchor?.frame, visible: visible)
    }
}

/// 弹窗摆在哪：纯几何，方便单测。
enum PopupPlacement {
    /// 优先以 `host`（发起弹窗的 app 窗口）为中心；`visible`（屏幕可见区域，
    /// 已避开菜单栏/程序坞）放不下时，改为 `visible` 的正中。
    static func origin(size: NSSize, host: NSRect?, visible: NSRect) -> NSPoint {
        if let host {
            let overHost = NSPoint(x: host.midX - size.width / 2, y: host.midY - size.height / 2)
            if visible.contains(NSRect(origin: overHost, size: size)) { return overHost }
        }
        return NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
    }
}

/// Esc 关窗（标准关闭按钮被隐藏了，靠响应链兜底）。
private final class CenteredWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}

#endif
