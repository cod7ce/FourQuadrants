import SwiftUI

/// 右侧「笔记」浮层：标题 + 收起箭头 + 富文本编辑器（每周独立）。
/// 展开时层级高于四象限，左边缘可拖拽调整宽度（松手才持久化）。
struct NotesPanel: View {
    let weekStart: Date
    @Binding var collapsed: Bool
    @Binding var width: Double

    static let minWidth: Double = 280
    static let maxWidth: Double = 680

    @State private var draft: Double?      // 拖拽中的临时宽度，避免每帧写 AppStorage
    @State private var baseWidth: Double = 0
    @State private var startX: CGFloat = 0

    private var currentWidth: Double { draft ?? width }

    var body: some View {
        content
            .frame(width: currentWidth)
            .frame(maxHeight: .infinity)
            // 左边缘分隔线：仅在内容区高度，不冒进标题栏
            .overlay(alignment: .leading) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 0.5)
            }
            // 拖拽手柄作为左边缘浮层，不占布局（否则会把工具栏往右推出一条缝）
            .overlay(alignment: .leading) { resizeHandle }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("notes.title")).font(.title3.bold())
                Spacer()
                Button { withAnimation(.easeInOut(duration: 0.15)) { collapsed = true } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("memo.collapse"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            MemoEditor(weekStart: weekStart)
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
                        let dx = Double(g.location.x - startX)   // 向左拖 dx<0 → 变宽
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

/// 笔记栏收起后的窄条（占布局空间，让四象限按剩余内部宽度渲染）。
struct NotesCollapsedStrip: View {
    @Binding var collapsed: Bool

    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { collapsed = false } } label: {
            Image(systemName: "note.text")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 44)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("notes.title"))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 0.5)
        }
    }
}
