import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var newLink = ""
    @State private var newTagName = ""
    @State private var newSubtask = ""

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $task.title, axis: .vertical)
                    .font(.headline)
                TextField("工单号（如 ONES2-2296709）",
                          text: Binding($task.issueKey))
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                TextField("备注", text: $task.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("象限") {
                Toggle("紧急", isOn: $task.isUrgent)
                Toggle("重要", isOn: $task.isImportant)
                HStack {
                    Image(systemName: task.quadrant.symbol)
                    Text(task.quadrant.title)
                    Spacer()
                    Text(task.quadrant.actionHint).foregroundStyle(.secondary)
                }
                .foregroundStyle(task.quadrant.color)
            }

            Section("日程") {
                OptionalDateRow(title: "截止日期", date: $task.dueDate)
                OptionalDateRow(title: "提醒", date: $task.remindAt)
            }

            Section("完成") {
                Toggle("已完成", isOn: Binding(
                    get: { task.isCompleted },
                    set: { _ in task.toggleCompleted() }
                ))
                if let done = task.completedAt {
                    LabeledContent("完成时间",
                                   value: done.formatted(.dateTime.month().day().hour().minute()))
                }
            }

            tagSection
            linkSection
            subtaskSection
        }
        .formStyle(.grouped)
        .navigationTitle(task.title.isEmpty ? "任务" : task.title)
        .onChange(of: task.remindAt) { _, _ in reschedule() }
        .onChange(of: task.isCompleted) { _, _ in reschedule() }
        .onChange(of: task.dueDate) { _, _ in try? context.save() }
    }

    // MARK: Tags

    private var tagSection: some View {
        Section("标签") {
            ForEach(allTags) { tag in
                Button {
                    toggle(tag)
                } label: {
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
                TextField("新建标签", text: $newTagName)
                Button("添加", action: addTag).disabled(newTagName.isEmpty)
            }
        }
    }

    private func toggle(_ tag: Tag) {
        var current = task.tags ?? []
        if let idx = current.firstIndex(where: { $0.id == tag.id }) {
            current.remove(at: idx)
        } else {
            current.append(tag)
        }
        task.tags = current
        try? context.save()
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let hex = TagPalette.hexes[allTags.count % TagPalette.hexes.count]
        let tag = Tag(name: name, colorHex: hex)
        context.insert(tag)
        task.tags = (task.tags ?? []) + [tag]
        newTagName = ""
        try? context.save()
    }

    // MARK: Links

    private var linkSection: some View {
        Section("链接") {
            ForEach(task.links, id: \.self) { link in
                LinkRow(urlString: link)
            }
            .onDelete { task.links.remove(atOffsets: $0); try? context.save() }
            HStack {
                TextField("添加链接 URL", text: $newLink)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                Button("添加", action: addLink)
                    .disabled(URL(string: newLink) == nil || newLink.isEmpty)
            }
        }
    }

    private func addLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        task.links.append(trimmed)
        newLink = ""
        try? context.save()
    }

    // MARK: Subtasks

    private var subtaskSection: some View {
        Section("子任务") {
            ForEach(task.sortedSubtasks) { sub in
                HStack {
                    CompletionToggle(isCompleted: sub.isCompleted) {
                        sub.toggleCompleted(); try? context.save()
                    }
                    Text(sub.title).strikethrough(sub.isCompleted)
                }
            }
            .onDelete(perform: deleteSubtasks)
            HStack {
                TextField("新建子任务", text: $newSubtask)
                Button("添加", action: addSubtask).disabled(newSubtask.isEmpty)
            }
        }
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let sub = TaskItem(title: title,
                           isUrgent: task.isUrgent,
                           isImportant: task.isImportant,
                           sortOrder: Double(task.sortedSubtasks.count))
        sub.parent = task
        context.insert(sub)
        newSubtask = ""
        try? context.save()
    }

    private func deleteSubtasks(_ offsets: IndexSet) {
        let subs = task.sortedSubtasks
        for i in offsets { context.delete(subs[i]) }
        try? context.save()
    }

    private func reschedule() {
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: SampleData.previewTask)
    }
    .modelContainer(previewContainer)
}
