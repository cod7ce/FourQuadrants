#if os(macOS)
import Testing
import AppKit
@testable import FourQuadrants

/// 弹窗摆位：能完整显示就跟着 app 窗口居中，否则退回屏幕居中。
struct PopupPlacementTests {

    private let screen = NSRect(x: 0, y: 0, width: 2560, height: 1400)   // 可见区域
    private let size = NSSize(width: 880, height: 660)

    @Test func centersOnAppWindowWhenItFits() {
        let host = NSRect(x: 700, y: 300, width: 1200, height: 800)      // 屏幕中部
        let p = PopupPlacement.origin(size: size, host: host, visible: screen)
        #expect(p == NSPoint(x: host.midX - 440, y: host.midY - 330))
    }

    @Test func fallsBackToScreenCenterWhenClippedHorizontally() {
        let host = NSRect(x: 2200, y: 300, width: 300, height: 800)      // 贴右边
        let p = PopupPlacement.origin(size: size, host: host, visible: screen)
        #expect(p == NSPoint(x: screen.midX - 440, y: screen.midY - 330))
    }

    @Test func fallsBackToScreenCenterWhenClippedVertically() {
        let host = NSRect(x: 700, y: 1100, width: 1200, height: 280)     // 贴顶部
        let p = PopupPlacement.origin(size: size, host: host, visible: screen)
        #expect(p == NSPoint(x: screen.midX - 440, y: screen.midY - 330))
    }

    @Test func screenCenterWhenNoAppWindow() {
        let p = PopupPlacement.origin(size: size, host: nil, visible: screen)
        #expect(p == NSPoint(x: screen.midX - 440, y: screen.midY - 330))
    }

    /// 弹窗比屏幕还大：仍旧屏幕居中（两边对称溢出），不要跟着 app 窗口跑偏。
    @Test func screenCenterWhenLargerThanScreen() {
        let huge = NSSize(width: 3000, height: 660)
        let host = NSRect(x: 700, y: 300, width: 1200, height: 800)
        let p = PopupPlacement.origin(size: huge, host: host, visible: screen)
        #expect(p == NSPoint(x: screen.midX - 1500, y: screen.midY - 330))
    }
}
#endif
