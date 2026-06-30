import SwiftUI
import SwiftData

/// 双击任务后弹出的可编辑 popover（Reminders 风格）。单列表单，关闭时自动保存。
struct TaskEditor: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var rich = RichContentStore()
    @State private var newLink = ""
    @State private var newTagName = ""
    @State private var newSubtask = ""

    var body: some View {
        Form {
            Section {
                TextField(L("detail.field.title"), text: $task.title, axis: .vertical)
                    .appFont(.headline)
                TextField(L("detail.field.issueKey.placeholder"), text: Binding($task.issueKey))
                    .autocorrectionDisabled()
            }

            Section(L("detail.content.title")) {
                RichTextEditor(store: rich, isEditable: true)
                    .frame(minHeight: 120)
            }

            Section(L("detail.section.quadrant")) {
                Toggle(L("detail.flag.urgent"), isOn: $task.isUrgent)
                Toggle(L("detail.flag.important"), isOn: $task.isImportant)
                HStack {
                    Image(systemName: task.quadrant.symbol)
                    Text(task.quadrant.title)
                    Spacer()
                    Text(task.quadrant.actionHint).foregroundStyle(.secondary)
                }
                .foregroundStyle(task.quadrant.color)
            }

            Section(L("detail.section.schedule")) {
                OptionalDateRow(title: L("detail.field.due"), date: $task.dueDate,
                                components: [.date])
                OptionalDateRow(title: L("detail.field.remind"), date: $task.remindAt,
                                components: [.date, .hourAndMinute], snapMinutes: 30)
            }

            Section(L("detail.section.completion")) {
                Toggle(L("detail.field.completed"), isOn: Binding(
                    get: { task.isCompleted },
                    set: { _ in task.toggleCompleted() }
                ))
            }

            tagSection
            linkSection
            subtaskSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420,
               minHeight: 420, idealHeight: 560)
        .onAppear { rich.reset(task.richContent) }
        .onDisappear { commit() }
    }

    // MARK: Sections

    private var tagSection: some View {
        Section(L("detail.section.tags")) {
            ForEach(allTags) { tag in
                Button { toggle(tag) } label: {
                    HStack {
                        TagChip(tag: tag)
                        Spacer()
                        if task.tagList.contains(where: { $0.id == tag.id }) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            HStack {
                TextField(L("detail.tag.new"), text: $newTagName)
                Button(L("action.add"), action: addTag).disabled(newTagName.isEmpty)
            }
        }
    }

    private var linkSection: some View {
        Section(L("detail.section.links")) {
            ForEach(task.links, id: \.self) { LinkRow(urlString: $0) }
                .onDelete { task.links.remove(atOffsets: $0) }
            HStack {
                TextField(L("detail.link.new"), text: $newLink)
                    .autocorrectionDisabled()
                Button(L("action.add"), action: addLink)
                    .disabled(newLink.isEmpty || URL(string: newLink) == nil)
            }
        }
    }

    private var subtaskSection: some View {
        Section(L("detail.section.subtasks")) {
            ForEach(task.sortedSubtasks) { sub in
                HStack {
                    CompletionToggle(isCompleted: sub.isCompleted) { sub.toggleCompleted() }
                    Text(sub.title).strikethrough(sub.isCompleted)
                }
            }
            .onDelete(perform: deleteSubtasks)
            HStack {
                TextField(L("detail.subtask.new"), text: $newSubtask)
                Button(L("action.add"), action: addSubtask).disabled(newSubtask.isEmpty)
            }
        }
    }

    // MARK: Actions

    private func commit() {
        task.richContent = RichText.data(rich.attributed)
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }

    private func toggle(_ tag: Tag) {
        var current = task.tags ?? []
        if let idx = current.firstIndex(where: { $0.id == tag.id }) {
            current.remove(at: idx)
        } else {
            current.append(tag)
        }
        task.tags = current
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let hex = TagPalette.hexes[allTags.count % TagPalette.hexes.count]
        let tag = Tag(name: name, colorHex: hex)
        context.insert(tag)
        task.tags = (task.tags ?? []) + [tag]
        newTagName = ""
    }

    private func addLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        task.links.append(trimmed)
        newLink = ""
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let sub = TaskItem(title: title,
                           isUrgent: task.isUrgent,
                           isImportant: task.isImportant,
                           sortOrder: Double(task.sortedSubtasks.count),
                           weekStart: task.weekStart)
        sub.parent = task
        context.insert(sub)
        newSubtask = ""
    }

    private func deleteSubtasks(_ offsets: IndexSet) {
        let subs = task.sortedSubtasks
        for i in offsets { context.delete(subs[i]) }
    }
}
