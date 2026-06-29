import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @State private var isEditing = false
    @State private var rich = RichContentStore()
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var segment: Segment = .basic
    enum Segment: String, CaseIterable {
        case basic, content
        var title: String { self == .basic ? L("detail.segment.basic") : L("detail.segment.content") }
    }
    #endif

    var body: some View {
        layout
            .navigationTitle(task.title.isEmpty ? L("detail.nav.task") : task.title)
            #if os(macOS)
            .navigationSubtitle(task.quadrant.title)
            #endif
            .toolbar { editToolbar }
            .onAppear { rich.reset(task.richContent) }
            .onChange(of: task.persistentModelID) { _, _ in
                if isEditing { context.rollback() }
                isEditing = false
                rich.reset(task.richContent)
            }
    }

    @ViewBuilder private var layout: some View {
        #if os(macOS)
        HSplitView {
            BasicInfoPane(task: task, isEditing: isEditing)
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 420)
            ContentPane(store: rich, isEditing: isEditing)
                .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        if hSize == .regular {
            HStack(spacing: 0) {
                BasicInfoPane(task: task, isEditing: isEditing)
                    .frame(maxWidth: 360)
                Divider()
                ContentPane(store: rich, isEditing: isEditing)
            }
        } else {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(8)
                Divider()
                if segment == .basic {
                    BasicInfoPane(task: task, isEditing: isEditing)
                } else {
                    ContentPane(store: rich, isEditing: isEditing)
                }
            }
        }
        #endif
    }

    @ToolbarContentBuilder private var editToolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("action.cancel")) {
                    context.rollback()
                    rich.reset(task.richContent)   // 丢弃富文本改动
                    isEditing = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("action.done")) {
                    task.richContent = RichText.data(rich.attributed)
                    try? context.save()
                    Task { await NotificationManager.shared.reschedule(for: task) }
                    isEditing = false
                }
            }
        } else {
            ToolbarItem {
                Button {
                    isEditing = true
                } label: {
                    Label(L("action.edit"), systemImage: "pencil")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: SampleData.previewTask)
    }
    .modelContainer(previewContainer)
}
