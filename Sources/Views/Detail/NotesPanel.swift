import SwiftUI

/// 右侧「笔记」栏：标题 + 收起箭头 + 富文本编辑器（每周独立）。
struct NotesPanel: View {
    let weekStart: Date
    @Binding var collapsed: Bool

    var body: some View {
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
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            MemoEditor(weekStart: weekStart)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

/// 笔记栏收起后，右侧留一条可点开的窄条。
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
        .background(.background)
    }
}
