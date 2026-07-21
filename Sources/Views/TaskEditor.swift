import SwiftUI
import SwiftData

/// 新建 / 编辑任务的统一大弹窗。左列：描述/子任务/链接；右列：象限点选/截止/提醒/标签。
struct TaskEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem
    /// 新建任务：关闭时若仍为空则丢弃。
    var isNew: Bool = false

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var rich = RichContentStore()
    @State private var newSubtask = ""
    @State private var newLink = ""
    @State private var newNote = ""
    @State private var newTagName = ""
    @State private var showNewTag = false
    @State private var showReminderPicker = false

    private var isSub: Bool { task.parent != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: 0) {
                leftColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                rightColumn
                    .frame(width: 320)
            }
            Divider()
            footer
        }
        .frame(width: isSub ? 720 : 880, height: 660)
        .onAppear { rich.reset(task.richContent) }
        .onDisappear(perform: commit)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            CompletionToggle(isCompleted: task.isCompleted) {
                task.toggleCompleted()
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                TextField(L("editor.title.placeholder"), text: $task.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .appFont(.title2, weight: .bold)
                    .lineLimit(1...3)
                HStack(spacing: 6) {
                    TextField(L("editor.issueKey.placeholder"), text: Binding($task.issueKey))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .fixedSize()
                    Text("·")
                    Text(L("editor.created") + " " + task.createdAt.formatted(.dateTime.month().day().locale(.app)))
                }
                .appFont(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Left column

    private var leftColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section(L("editor.description")) {
                    RichTextEditor(store: rich, isEditable: true)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }

                notesBlock

                if !isSub { subtasksBlock }
                linksBlock
            }
            .padding(20)
        }
    }

    private var notesBlock: some View {
        let notes = task.sortedNotes
        return VStack(alignment: .leading, spacing: 8) {
            Text(L("editor.notes")).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            ForEach(notes) { note in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 5, height: 5).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(note.text).fixedSize(horizontal: false, vertical: true)
                        Text(note.createdAt.formatted(.dateTime.month().day().hour().minute().locale(.app)))
                            .appFont(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Button { context.delete(note) } label: {
                        Image(systemName: "xmark").appFont(.caption2).foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "text.bubble").foregroundStyle(.secondary)
                TextField(L("editor.note.add"), text: $newNote, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .onSubmit(addNote)
            }
            .padding(.top, 2)
        }
    }

    private var subtasksBlock: some View {
        let subs = task.sortedSubtasks
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("editor.subtasks")).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
                Spacer()
                Text("\(subs.filter(\.isCompleted).count) / \(subs.count)")
                    .appFont(.caption, monospacedDigit: true).foregroundStyle(.secondary)
            }
            Divider()
            ForEach(subs) { sub in
                HStack(spacing: 10) {
                    CompletionToggle(isCompleted: sub.isCompleted) { sub.toggleCompleted() }
                    Text(sub.title.isEmpty ? L("task.default.title") : sub.title)
                        .strikethrough(sub.isCompleted)
                        .foregroundStyle(sub.isCompleted ? .secondary : Color.appLabel)
                    Spacer(minLength: 0)
                    Button { context.delete(sub) } label: {
                        Image(systemName: "xmark").appFont(.caption2).foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .draggable(TaskTransfer(taskUUID: sub.taskUUID))
                .dropDestination(for: TaskTransfer.self) { items, _ in
                    for it in items {
                        TaskMutations.reorder(draggedUUID: it.taskUUID, before: sub, ordered: subs, in: context)
                    }
                    return !items.isEmpty
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(.secondary)
                TextField(L("editor.subtask.add"), text: $newSubtask)
                    .textFieldStyle(.plain)
                    .onSubmit(addSubtask)
            }
            .padding(.top, 2)
        }
    }

    private var linksBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("editor.links")).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            ForEach(task.links, id: \.self) { link in
                HStack {
                    LinkRow(urlString: link)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { task.links.removeAll { $0 == link } } label: {
                        Image(systemName: "xmark").appFont(.caption2).foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "link").foregroundStyle(.secondary)
                TextField(L("editor.link.add"), text: $newLink)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit(addLink)
            }
        }
    }

    // MARK: - Right column

    private var rightColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !isSub { section(L("editor.quadrant")) { quadrantPicker } }
                section(L("editor.due")) { dueBlock }
                section(L("editor.remind")) { reminderBlock }
                if !isSub { section(L("editor.tags")) { tagsBlock } }
            }
            .padding(20)
        }
    }

    private var quadrantPicker: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 20, height: 1)
                colHeader(L("editor.urgent"))
                colHeader(L("editor.notUrgent"))
            }
            GridRow {
                rowHeader(L("editor.important"))
                qCard(.urgentImportant)
                qCard(.important)
            }
            GridRow {
                rowHeader(L("editor.notImportant"))
                qCard(.urgent)
                qCard(.neither)
            }
        }
    }

    private func colHeader(_ t: String) -> some View {
        Text(t).appFont(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }
    private func rowHeader(_ t: String) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(t.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
            }
        }
        .appFont(.caption2).foregroundStyle(.secondary).frame(width: 16)
    }

    private func qCard(_ q: Quadrant) -> some View {
        let selected = task.quadrant == q
        return Button { task.move(to: q) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(q.title).appFont(.subheadline, weight: .semibold).foregroundStyle(q.color)
                Text(q.actionHint).appFont(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .padding(10)
            .background(q.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(q.color, lineWidth: selected ? 2 : 0))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark").appFont(.caption, weight: .bold)
                        .foregroundStyle(q.color).padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var dueBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let due = task.dueDate {
                pill(icon: "calendar", text: dateText(due), tint: .green) {
                    task.dueDate = nil
                }
            }
            FlowLayout(spacing: 8) {
                quickDate(L("editor.due.today"), Week.calendar.startOfDay(for: .now))
                quickDate(L("editor.due.tomorrow"), Week.calendar.date(byAdding: .day, value: 1, to: Week.calendar.startOfDay(for: .now))!)
                quickDate(L("editor.due.thisWeek"), thisFriday())
                quickDate(L("editor.due.nextMon"), nextMonday())
            }
        }
    }

    private func quickDate(_ label: String, _ date: Date) -> some View {
        Button { task.dueDate = date } label: {
            Text(label).appFont(.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3])))
        }
        .buttonStyle(.plain)
    }

    private var reminderBlock: some View {
        Group {
            if let remind = task.remindAt {
                pill(icon: "bell", text: dateTimeText(remind), tint: .orange) { task.remindAt = nil }
                    .onTapGesture { showReminderPicker = true }
            } else {
                Button { task.remindAt = defaultRemind(); showReminderPicker = true } label: {
                    dashedPill(icon: "bell", text: L("editor.remind.add"))
                }
                .buttonStyle(.plain)
            }
        }
        .popover(isPresented: $showReminderPicker) {
            DatePicker("", selection: Binding(get: { task.remindAt ?? defaultRemind() },
                                              set: { task.remindAt = snap($0) }),
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .frame(width: 300)
        }
    }

    private var tagsBlock: some View {
        FlowLayout(spacing: 8) {
            ForEach(allTags) { tag in
                let on = task.tagList.contains { $0.id == tag.id }
                Button { toggleTag(tag) } label: {
                    HStack(spacing: 5) {
                        if on { Circle().fill(tag.color).frame(width: 6, height: 6) }
                        Text(tag.name).appFont(.caption)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundStyle(on ? tag.color : .secondary)
                    .background(on ? tag.color.opacity(0.14) : .clear, in: Capsule())
                    .overlay {
                        if !on {
                            Capsule().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Button { showNewTag = true } label: {
                dashedPill(icon: "plus", text: L("editor.tag.new"))
            }
            .buttonStyle(.plain)
        }
        .alert(L("editor.tag.new"), isPresented: $showNewTag) {
            TextField(L("detail.tag.new"), text: $newTagName)
            Button(L("action.add"), action: addTag)
            Button(L("action.cancel"), role: .cancel) { newTagName = "" }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(role: .destructive) { deleteTask() } label: {
                Label(L("editor.delete"), systemImage: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)

            Spacer()

            Text(L("editor.autosave")).appFont(.caption).foregroundStyle(.secondary)
            Button(L("editor.done")) { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    // MARK: - Bits

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            content()
        }
    }

    private func pill(icon: String, text: String, tint: Color, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).appFont(.caption)
            Text(text).appFont(.caption)
            Button(action: onClear) { Image(systemName: "xmark").appFont(.caption2) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private func dashedPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).appFont(.caption)
            Text(text).appFont(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3])))
    }

    // MARK: - Actions

    private func commit() {
        // 关闭时把还没回车提交的输入一并保存，避免「填了没回车就点完成」导致丢失。
        addNote()
        addSubtask()
        addLink()
        if isNew, isEmptyTask {
            context.delete(task)
            try? context.save()
            return
        }
        task.richContent = RichText.data(rich.attributed)
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }

    private var isEmptyTask: Bool {
        task.title.trimmingCharacters(in: .whitespaces).isEmpty
            && task.sortedSubtasks.isEmpty && task.links.isEmpty
            && task.sortedNotes.isEmpty
            && (task.issueKey ?? "").isEmpty && rich.attributed.length == 0
    }

    private func deleteTask() {
        let toDelete = task
        dismiss()
        context.delete(toDelete)
        try? context.save()
    }

    private func toggleTag(_ tag: Tag) {
        var current = task.tags ?? []
        if let idx = current.firstIndex(where: { $0.id == tag.id }) { current.remove(at: idx) }
        else { current.append(tag) }
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

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let sub = TaskItem(title: title,
                           isUrgent: task.isUrgent, isImportant: task.isImportant,
                           sortOrder: Double(task.sortedSubtasks.count), weekStart: task.weekStart)
        sub.parent = task
        context.insert(sub)
        newSubtask = ""
    }

    private func addLink() {
        let trimmed = newLink.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else { return }
        task.links.append(trimmed)
        newLink = ""
    }

    private func addNote() {
        let text = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = TaskNote(text: text)
        note.task = task
        context.insert(note)
        newNote = ""
    }

    // MARK: - Date helpers

    private func dateText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = .app; f.dateFormat = "yyyy/M/d EEE"
        return f.string(from: d)
    }
    private func dateTimeText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = .app; f.dateFormat = "M/d HH:mm"
        return f.string(from: d)
    }
    /// 本周（当前周）的周五。
    private func thisFriday() -> Date {
        Week.calendar.date(byAdding: .day, value: 4, to: Week.currentStart) ?? Week.currentStart
    }
    private func nextMonday() -> Date {
        let cal = Week.calendar
        let today = cal.startOfDay(for: .now)
        let wd = cal.component(.weekday, from: today) // 1=Sun..7=Sat
        let delta = ((9 - wd) % 7)
        return cal.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: today)!
    }
    private func defaultRemind() -> Date {
        let base = task.dueDate ?? .now
        return snap(Week.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
    }
    private func snap(_ d: Date) -> Date {
        let cal = Week.calendar
        let m = cal.component(.minute, from: d)
        let snapped = (m / 30) * 30
        return cal.date(bySettingHour: cal.component(.hour, from: d), minute: snapped, second: 0, of: d) ?? d
    }
}

/// 简单的流式换行布局（标签胶囊等）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
