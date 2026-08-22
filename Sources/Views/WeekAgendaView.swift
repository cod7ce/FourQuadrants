import SwiftUI
import SwiftData

/// 「本周」议程：按截止日期把任务排到周一~周日；逾期（本周内、已过今天、未完成）单列顶部。
/// 没有截止日期的任务不出现在此，位于右侧「待安排」，可拖到某天来排期。
struct WeekAgendaView: View {
    @Environment(\.modelContext) private var context
    @Binding var selectedTask: TaskItem?
    @Binding var weekStart: Date
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var newTask: TaskItem?

    // MARK: 计算

    private var weekEnd: Date {
        Week.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }
    private var todayStart: Date { Week.calendar.startOfDay(for: .now) }
    private var days: [Date] {
        (0..<7).compactMap { Week.calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// 任务在议程上归属的日期：已完成用「完成日」，未完成用「截止日」。
    /// 于是完成的任务会落到实际完成那天，而截止日仍原样保留。
    private func agendaDate(_ t: TaskItem) -> Date? {
        t.isCompleted ? (t.completedAt ?? t.dueDate) : t.dueDate
    }

    /// 本周议程里的任务（含子任务；未完成按截止日、已完成按完成日落在本周）。
    /// 子任务有自己的截止日，也按它自己的日期出现在对应那天。
    private var weekTasks: [TaskItem] {
        allTasks.filter { t in
            guard let d = agendaDate(t) else { return false }
            return d >= weekStart && d < weekEnd
        }
    }

    /// 逾期：本周内、截止日在今天之前、且未完成。
    private var overdue: [TaskItem] {
        weekTasks.filter { t in
            guard !t.isCompleted, let due = t.dueDate else { return false }
            return Week.calendar.startOfDay(for: due) < todayStart
        }
    }

    private func tasks(on day: Date) -> [TaskItem] {
        let overdueIDs = Set(overdue.map(\.taskUUID))
        return weekTasks.filter { t in
            guard let d = agendaDate(t) else { return false }
            return Week.calendar.isDate(d, inSameDayAs: day) && !overdueIDs.contains(t.taskUUID)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderBar(weekStart: $weekStart, tasks: weekTasks)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !overdue.isEmpty { overdueSection }

                    ForEach(days, id: \.self) { day in
                        DaySection(day: day,
                                   tasks: tasks(on: day),
                                   selectedTask: $selectedTask)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(L("sidebar.thisWeek"))
        .mainToolbar(week: weekStart, weekTasks: weekTasks) { newTask = makeTask() }
        .sheet(item: $newTask) { TaskEditor(task: $0, isNew: true) }
    }

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(String(format: L("agenda.overdue"), overdue.count))
                    .appFont(.subheadline, weight: .semibold)
            }
            .foregroundStyle(.red)

            ForEach(overdue) { task in
                AgendaRow(task: task, overdue: true,
                          isSelected: selectedTask?.persistentModelID == task.persistentModelID,
                          onSelect: { selectedTask = task })
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 14)
    }

    private func makeTask() -> TaskItem {
        let flags = Quadrant.urgentImportant.flags
        let t = TaskItem(isUrgent: flags.isUrgent, isImportant: flags.isImportant, weekStart: weekStart)
        // 新建默认排到今天（若今天在本周内），否则排到周一，保证出现在议程里。
        t.dueDate = (todayStart >= weekStart && todayStart < weekEnd) ? todayStart : weekStart
        context.insert(t)
        return t
    }
}

// MARK: - 某一天的分组

private struct DaySection: View {
    @Environment(\.modelContext) private var context
    let day: Date
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?
    @State private var dropTargeted = false

    private var isToday: Bool { Week.calendar.isDateInToday(day) }
    private var done: Int { tasks.filter(\.isCompleted).count }
    private var todo: Int { tasks.count - done }

    private var summary: String {
        if tasks.isEmpty { return L("agenda.noTasks") }
        if todo == 0 { return String(format: L("agenda.completedOnly"), done) }
        if done == 0 { return String(format: L("agenda.todoCount"), todo) }
        return String(format: L("agenda.todoCount"), todo) + " · " + String(format: L("agenda.doneCount"), done)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            VStack(alignment: .leading, spacing: 14) {
                ForEach(tasks) { task in
                    AgendaRow(task: task,
                              isSelected: selectedTask?.persistentModelID == task.persistentModelID,
                              onSelect: { selectedTask = task })
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(dropTargeted ? Color.accentColor.opacity(0.10) : .clear)
                .padding(.horizontal, -8)
        }
        .overlay(alignment: .bottom) { Divider() }
        .dropDestination(for: TaskTransfer.self) { items, _ in
            for it in items { TaskMutations.schedule(uuid: it.taskUUID, onDay: day, in: context) }
            return !items.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(.app)))
                .appFont(.subheadline, weight: .semibold)
                .foregroundStyle(isToday ? Color.accentColor : Color.appLabel)
            Text(day.formatted(.dateTime.month().day().locale(.app)))
                .appFont(.subheadline).foregroundStyle(.secondary)
            if isToday {
                Text(L("agenda.today"))
                    .appFont(.caption2, weight: .semibold).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
            Spacer()
            Text(summary).appFont(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - 议程任务行

private struct AgendaRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Environment(\.fontScale) private var fontScale
    @Bindable var task: TaskItem
    var overdue: Bool = false
    var isSelected: Bool = false
    var onSelect: () -> Void = {}
    @State private var showPopover = false

    private var subs: [TaskItem] { task.sortedSubtasks }
    private var linkActive: Bool { optionHeld && !task.urls.isEmpty }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button { toggle() } label: {
                TaskCheckbox(isCompleted: task.isCompleted)
            }
            .buttonStyle(.plain)
            .alignedToFirstLine(scale: fontScale)

            Circle().fill(task.quadrant.color).frame(width: 8, height: 8)
                .alignedToFirstLine(scale: fontScale)

            VStack(alignment: .leading, spacing: 2) {
                TaggedTitleText(task: task,
                                strikethrough: task.isCompleted,
                                underline: linkActive,
                                color: linkActive ? .accentColor
                                    : (task.isCompleted ? .secondary : Color.appLabel))
                if let parent = task.parent {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.turn.down.right").imageScale(.small)
                        Text(parent.title.isEmpty ? L("task.default.title") : parent.title)
                    }
                    .appFont(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
                if !task.isCompleted { TaskMetaLine(task: task) }
            }

            Spacer(minLength: 8)

            if !subs.isEmpty {
                Text("\(subs.filter(\.isCompleted).count)/\(subs.count)")
                    .appFont(.caption, monospacedDigit: true)
                    .foregroundStyle(.secondary)
            }

            if overdue, let due = task.dueDate {
                Text(String(format: L("agenda.originalDue"),
                            due.formatted(.dateTime.month().day().locale(.app))))
                    .appFont(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .highPriorityGesture(
            TapGesture().modifiers(.option).onEnded {
                if let url = task.urls.first { openURL(url) }
            }
        )
        #endif
        .onTapGesture(count: 2) { showPopover = true }
        .onTapGesture { onSelect() }
        .draggable(TaskTransfer(taskUUID: task.taskUUID))
        .sheet(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    private func toggle() {
        task.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}
