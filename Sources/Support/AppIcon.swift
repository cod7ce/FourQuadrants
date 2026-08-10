import SwiftUI

/// 图标集（按设计师输出的 SVG 1:1 移植为 SwiftUI Path）。
/// 规范：24×24 · 1.8 描边 · 线端圆头 · stroke=currentColor（跟随 foregroundStyle / 明暗自适应）。
enum AppIcon {
    case overview, thisWeek, calendar, inbox, settings, sidebar, carry, share, notes, new
}

struct AppIconView: View {
    let icon: AppIcon
    var size: CGFloat = 18

    /// 半透明填充部件（高亮周行 / 左栏底）的不透明度。
    private var fillOpacity: Double {
        switch icon {
        case .thisWeek: return 0.22
        case .sidebar:  return 0.16
        default:        return 1
        }
    }

    var body: some View {
        ZStack {
            IconFill(icon: icon).opacity(fillOpacity)
            IconStroke(icon: icon)
                .stroke(style: StrokeStyle(lineWidth: 1.8 * size / 24, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 描边

private struct IconStroke: Shape {
    let icon: AppIcon

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        func seg(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            p.move(to: pt(x1, y1)); p.addLine(to: pt(x2, y2))
        }
        func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            p.addPath(Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s),
                           cornerRadius: r * s))
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
        }

        switch icon {
        case .overview:
            rrect(4, 4, 7, 7, 1.6); rrect(13, 4, 7, 7, 1.6)
            rrect(4, 13, 7, 7, 1.6); rrect(13, 13, 7, 7, 1.6)

        case .thisWeek, .calendar:
            rrect(3, 4.5, 18, 16, 2.5)
            seg(3, 9, 21, 9)
            seg(7.5, 2.5, 7.5, 6); seg(16.5, 2.5, 16.5, 6)

        case .inbox:
            // 顶盖
            p.move(to: pt(4, 13)); p.addLine(to: pt(6.2, 5.6))
            p.addQuadCurve(to: pt(7.6, 4.6), control: pt(6.5, 4.6))
            p.addLine(to: pt(16.4, 4.6))
            p.addQuadCurve(to: pt(17.8, 5.6), control: pt(17.5, 4.6))
            p.addLine(to: pt(20, 13))
            // 箱体
            p.move(to: pt(4, 13)); p.addLine(to: pt(4, 18.4))
            p.addQuadCurve(to: pt(5.6, 20), control: pt(4, 20))
            p.addLine(to: pt(18.4, 20))
            p.addQuadCurve(to: pt(20, 18.4), control: pt(20, 20))
            p.addLine(to: pt(20, 13))
            // 收纳口
            p.move(to: pt(4, 13)); p.addLine(to: pt(8, 13)); p.addLine(to: pt(9.3, 15.2))
            p.addLine(to: pt(14.7, 15.2)); p.addLine(to: pt(16, 13)); p.addLine(to: pt(20, 13))

        case .settings:
            circle(12, 12, 6.2); circle(12, 12, 2.3)
            seg(18.2, 12, 20.3, 12);   seg(16.38, 16.38, 17.87, 17.87)
            seg(12, 18.2, 12, 20.3);   seg(7.62, 16.38, 6.13, 17.87)
            seg(5.8, 12, 3.7, 12);     seg(7.62, 7.62, 6.13, 6.13)
            seg(12, 5.8, 12, 3.7);     seg(16.38, 7.62, 17.87, 6.13)

        case .sidebar:
            rrect(3, 4.5, 18, 15, 2.5)
            seg(9, 4.5, 9, 19.5)

        case .carry:
            p.move(to: pt(4, 15)); p.addLine(to: pt(4, 12.5))
            p.addQuadCurve(to: pt(7.5, 9), control: pt(4, 9))
            p.addLine(to: pt(17, 9))
            p.move(to: pt(13, 4.7)); p.addLine(to: pt(18, 9)); p.addLine(to: pt(13, 13.3))

        case .share:
            seg(12, 3.5, 12, 14.5)
            p.move(to: pt(8, 7)); p.addLine(to: pt(12, 3.5)); p.addLine(to: pt(16, 7))
            p.move(to: pt(6, 12)); p.addLine(to: pt(6, 17.5))
            p.addQuadCurve(to: pt(7.5, 19), control: pt(6, 19))
            p.addLine(to: pt(16.5, 19))
            p.addQuadCurve(to: pt(18, 17.5), control: pt(18, 19))
            p.addLine(to: pt(18, 12))

        case .notes:
            rrect(4.5, 3.5, 15, 17, 2.6)
            seg(8, 8.5, 16, 8.5); seg(8, 12, 16, 12); seg(8, 15.5, 13, 15.5)

        case .new:
            seg(12, 5, 12, 19); seg(5, 12, 19, 12)
        }
        return p
    }
}

// MARK: - 填充（半透明高亮 / 实心密度点）

private struct IconFill: Shape {
    let icon: AppIcon

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        switch icon {
        case .thisWeek:
            p.addPath(Path(roundedRect: CGRect(x: 5.5 * s, y: 12 * s, width: 13 * s, height: 3.4 * s),
                           cornerRadius: 1.7 * s))
        case .sidebar:
            p.addPath(Path(roundedRect: CGRect(x: 3 * s, y: 4.5 * s, width: 6 * s, height: 15 * s),
                           cornerRadius: 2.5 * s))
        case .calendar:
            for (cx, cy) in [(8, 13), (12, 13), (16, 13), (8, 17), (12, 17)] as [(CGFloat, CGFloat)] {
                p.addEllipse(in: CGRect(x: (cx - 1) * s, y: (cy - 1) * s, width: 2 * s, height: 2 * s))
            }
        default:
            break
        }
        return p
    }
}
