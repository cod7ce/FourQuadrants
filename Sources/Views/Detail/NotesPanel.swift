import SwiftUI

/// 笔记：从标题栏图标以悬浮弹窗（popover）方式展示，不再常驻侧边。
struct NotesPopover: View {
    let weekStart: Date
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L("notes.title")).font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider()

            MemoEditor(weekStart: weekStart)
        }
        .frame(width: 400, height: 560)
    }
}
