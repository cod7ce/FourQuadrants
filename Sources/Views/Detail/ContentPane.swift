import SwiftUI

/// 详情右栏：详细内容。一个可直接编辑的富文本区，支持文字与粘贴的图片（图文混排）。
struct ContentPane: View {
    let store: RichContentStore
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("detail.content.title")).font(.headline)
                Spacer()
                if isEditing {
                    Text(L("detail.content.hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            Divider()
            RichTextEditor(store: store, isEditable: isEditing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
