import SwiftUI

enum RightPanelMode: String { case notes, inbox }

/// 右侧内容面板：按 `mode` 显示「笔记」或「待安排 Inbox」。左边缘可拖拽调宽。
struct RightPanel: View {
    let weekStart: Date
    let mode: RightPanelMode
    @Binding var width: Double

    static let minWidth: Double = 280
    static let maxWidth: Double = 680

    @State private var draft: Double?
    @State private var baseWidth: Double = 0
    @State private var startX: CGFloat = 0

    private var currentWidth: Double { draft ?? width }

    var body: some View {
        content
            .frame(width: currentWidth)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 0.5)
            }
            .overlay(alignment: .leading) { resizeHandle }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode == .notes ? L("notes.title") : L("inbox.title")).font(.title3.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            if mode == .notes {
                MemoEditor(weekStart: weekStart)
            } else {
                InboxView(weekStart: weekStart)
            }
        }
    }

    /// 左边缘拖拽手柄：用全局坐标计算，避免手柄随面板移动造成的抖动。
    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { g in
                        if draft == nil { baseWidth = width; startX = g.location.x }
                        let dx = Double(g.location.x - startX)
                        draft = min(max(Self.minWidth, baseWidth - dx), Self.maxWidth)
                    }
                    .onEnded { _ in
                        if let d = draft { width = d }
                        draft = nil
                    }
            )
            #if os(macOS)
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            #endif
    }
}

/// 右侧图标栏（置顶）：笔记 / 待安排，点击打开对应视图；点当前项收起。
struct RightRail: View {
    @Binding var mode: RightPanelMode
    @Binding var collapsed: Bool

    var body: some View {
        VStack(spacing: 6) {
            railButton(.notes, "note.text", L("notes.title"))
            railButton(.inbox, "tray", L("inbox.title"))
            Spacer()
        }
        .padding(.top, 12)
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 0.5)
        }
    }

    private func railButton(_ m: RightPanelMode, _ icon: String, _ help: String) -> some View {
        let active = !collapsed && mode == m
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if collapsed { collapsed = false; mode = m }
                else if mode == m { collapsed = true }
                else { mode = m }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(active ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(active ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
