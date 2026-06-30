import SwiftUI

/// 是否正按住 Option（用于提示可点击的链接）。
struct OptionHeldKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var optionHeld: Bool {
        get { self[OptionHeldKey.self] }
        set { self[OptionHeldKey.self] = newValue }
    }
}

#if os(macOS)
import AppKit

/// 监听 Option 键的按下/松开。
@MainActor
final class ModifierWatcher: ObservableObject {
    @Published var option = false
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.option = event.modifierFlags.contains(.option)
            return event
        }
        let nc = NotificationCenter.default
        // 失焦时复位（此时松开的事件发生在别的 App，本监听器收不到）
        observers.append(nc.addObserver(forName: NSApplication.didResignActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            self?.option = false
        })
        // 重新激活时按当前实际修饰键同步
        observers.append(nc.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            self?.option = NSEvent.modifierFlags.contains(.option)
        })
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
#endif
