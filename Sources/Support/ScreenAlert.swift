#if os(macOS)
import AppKit

/// 屏幕居中的模态提示框（NSAlert 是 app 级模态，落在屏幕中间，
/// 而 SwiftUI 的 .alert / .confirmationDialog 在 macOS 上是挂在窗口上的 sheet）。
@MainActor
enum ScreenAlert {
    /// 弹出选项框，返回被点按钮的下标（按 `buttons` 顺序，从 0 开始）。
    /// 末位按钮建议是「取消」——NSAlert 会自动把它绑到 Esc。
    @discardableResult
    static func choose(title: String, message: String = "", buttons: [String]) -> Int {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for b in buttons { alert.addButton(withTitle: b) }
        alert.buttons.last?.keyEquivalent = "\u{1b}"   // 末位（取消）绑 Esc；中文标题不会自动绑
        place(alert)
        return alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    /// 单行输入框，点「取消」或留空返回 nil。
    static func input(title: String, placeholder: String, ok: String, cancel: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: ok)
        alert.addButton(withTitle: cancel)
        alert.buttons.last?.keyEquivalent = "\u{1b}"   // Esc = 取消

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        place(alert)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// 和其它弹窗同一套规则：以 app 窗口为中心，放不下才退回屏幕正中。
    private static func place(_ alert: NSAlert) {
        let host = NSApp.keyWindow ?? NSApp.mainWindow
        alert.layout()                                  // 先定尺寸，再摆位
        let window = alert.window
        guard let visible = (host?.screen ?? NSScreen.main)?.visibleFrame else { return }
        let origin = PopupPlacement.origin(size: window.frame.size,
                                           host: host?.frame,
                                           visible: visible)
        window.setFrameOrigin(origin)
        // runModal 起来后 AppKit 会再按自己的规矩摆一次，这里抢回来
        DispatchQueue.main.async { window.setFrameOrigin(origin) }
    }
}
#endif
