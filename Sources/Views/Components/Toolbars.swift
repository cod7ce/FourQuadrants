import SwiftUI

/// 主视图右上角固定成一组：笔记 + 新建任务（顺序与「日历」一致）。
struct NotesAddToolbar: ToolbarContent {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    let onAdd: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {
            #if os(macOS)
            Button { openWindow(id: "notes") } label: {
                Image(systemName: "note.text").foregroundStyle(.secondary)
            }
            .help(L("notes.title"))
            #endif
            Button(action: onAdd) {
                Label(L("action.create"), systemImage: "plus")
            }
        }
    }
}
