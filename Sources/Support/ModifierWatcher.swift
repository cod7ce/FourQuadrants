import SwiftUI

/// 是否正按住 Command（用于提示可点击的链接）。
struct CommandHeldKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var commandHeld: Bool {
        get { self[CommandHeldKey.self] }
        set { self[CommandHeldKey.self] = newValue }
    }
}

#if os(macOS)
import AppKit

/// 监听 Command 键的按下/松开。
@MainActor
final class ModifierWatcher: ObservableObject {
    @Published var command = false
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.command = event.modifierFlags.contains(.command)
            return event
        }
        let nc = NotificationCenter.default
        // 失焦时复位（此时松开 ⌘ 的事件发生在别的 App，本监听器收不到）
        observers.append(nc.addObserver(forName: NSApplication.didResignActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            self?.command = false
        })
        // 重新激活时按当前实际修饰键同步
        observers.append(nc.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            self?.command = NSEvent.modifierFlags.contains(.command)
        })
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
#endif
