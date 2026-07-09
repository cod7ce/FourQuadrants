import SwiftUI
import SwiftData

/// 日历模块：月网格，按象限着色的任务圆点，右侧当日详情。
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selectedTask: TaskItem?
    @Binding var weekStart: Date
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    @State private var anchor = Week.calendar.startOfDay(for: .now)      // 当前显示的月锚点
    @State private var selectedDay = Week.calendar.startOfDay(for: .now)
    @State private var newTask: TaskItem?

    // MARK: - 日期计算

    private var cal: Calendar { Week.calendar }
    private var today: Date { cal.startOfDay(for: .now) }

    private var monthDays: [Date] {
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: anchor)) ?? anchor
        let gridStart = Week.start(of: firstOfMonth)
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
    private var rows: [[Date]] { stride(from: 0, to: monthDays.count, by: 7).map { Array(monthDays[$0..<$0+7]) } }

    /// 每天的任务（按 agendaDate 归类，含子任务）。
    private var tasksByDay: [Date: [TaskItem]] {
        var dict: [Date: [TaskItem]] = [:]
        for t in allTasks {
            guard let d = t.agendaDate else { continue }
            dict[cal.startOfDay(for: d), default: []].append(t)
        }
        return dict
    }
    private func tasks(on day: Date) -> [TaskItem] { tasksByDay[cal.startOfDay(for: day)] ?? [] }

    private var weekdaySymbols: [String] {
        let syms = cal.veryShortWeekdaySymbols                    // 以周日为首
        return (0..<7).map { syms[(1 + $0) % 7] }                // 重排为「一…日」
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            calendarMain
            Divider()
            CalDayPanel(day: selectedDay,
                        tasks: tasks(on: selectedDay),
                        inboxCount: inboxCount,
                        selectedTask: $selectedTask)
                .frame(width: 320)
        }
        .navigationTitle(L("sidebar.calendar"))
        .toolbar {
            ToolbarItem {
                Button { newTask = makeTask() } label: { Label(L("action.create"), systemImage: "plus") }
            }
        }
        .sheet(item: $newTask) { TaskEditor(task: $0, isNew: true) }
    }

    private var calendarMain: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 14)
            weekdayHeader.padding(.horizontal, 24)
            grid.padding(.horizontal, 24).padding(.top, 4)
            legend.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            navButton("chevron.left") { step(-1) }
            Text(monthTitle).font(.title2.bold())
            navButton("chevron.right") { step(1) }
            Spacer()
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { day in
                        CalendarCell(day: day,
                                     inMonth: cal.isDate(day, equalTo: anchor, toGranularity: .month),
                                     isToday: cal.isDate(day, inSameDayAs: today),
                                     isSelected: cal.isDate(day, inSameDayAs: selectedDay),
                                     isWeekend: cal.isDateInWeekend(day),
                                     tasks: tasks(on: day)) {
                            selectedDay = cal.startOfDay(for: day)
                            if !cal.isDate(day, equalTo: anchor, toGranularity: .month) { anchor = day }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(Quadrant.allCases) { q in
                HStack(spacing: 5) {
                    Circle().fill(q.color).frame(width: 7, height: 7)
                    Text(q.title).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let c = cal.dateComponents([.year, .month], from: anchor)
        return String(format: L("cal.yearMonth"), c.year ?? 0, c.month ?? 0)
    }

    private var inboxCount: Int {
        allTasks.filter { $0.parent == nil && !$0.isCompleted && $0.dueDate == nil }.count
    }

    private func step(_ dir: Int) {
        anchor = cal.date(byAdding: .month, value: dir, to: anchor) ?? anchor
    }

    private func makeTask() -> TaskItem {
        let flags = Quadrant.urgentImportant.flags
        let t = TaskItem(isUrgent: flags.isUrgent, isImportant: flags.isImportant,
                         weekStart: Week.start(of: selectedDay))
        t.dueDate = selectedDay
        context.insert(t)
        return t
    }
}

// MARK: - 日历格子

private struct CalendarCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
    let tasks: [TaskItem]
    let onTap: () -> Void

    private var dayNumber: String { "\(Week.calendar.component(.day, from: day))" }
    private var dots: [TaskItem] { Array(tasks.prefix(7)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            numberView
            HStack(spacing: 4) {
                ForEach(dots) { t in
                    Circle().fill(t.quadrant.color).frame(width: 6, height: 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cellBackground)
        .overlay {
            Rectangle().strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        }
        .overlay {
            if isSelected {
                Rectangle().strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var cellBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.08) }
        if isWeekend { return Color.secondary.opacity(0.06) }   // 周末淡背景
        return .clear
    }

    @ViewBuilder private var numberView: some View {
        if isToday {
            Text(dayNumber)
                .font(.callout.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
        } else {
            Text(dayNumber)
                .font(.callout)
                .foregroundStyle(Color.appLabel)
                .opacity(inMonth ? 1 : 0.35)
                .frame(width: 24, height: 24, alignment: .center)
        }
    }
}

// MARK: - 右侧当日详情

private struct CalDayPanel: View {
    let day: Date
    let tasks: [TaskItem]
    let inboxCount: Int
    @Binding var selectedTask: TaskItem?

    private var cal: Calendar { Week.calendar }
    private var active: [TaskItem] { tasks.filter { !$0.isCompleted } }
    private var done: [TaskItem] { tasks.filter(\.isCompleted) }
    private var isToday: Bool { cal.isDateInToday(day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(active) { row($0) }
                    if !done.isEmpty {
                        Text(String(format: L("grid.completedCount"), done.count))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 4)
                        ForEach(done) { row($0) }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "tray")
                Text(String(format: L("cal.inboxFooter"), inboxCount))
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(day.formatted(.dateTime.month().day().weekday(.wide).locale(.app)))
                    .font(.headline)
                if isToday {
                    Text(L("agenda.today"))
                        .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
                Spacer()
            }
            Text(summary).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
    }

    private var summary: String {
        if tasks.isEmpty { return L("agenda.noTasks") }
        var parts: [String] = []
        if !active.isEmpty { parts.append(String(format: L("agenda.todoCount"), active.count)) }
        if !done.isEmpty { parts.append(String(format: L("cal.doneCount"), done.count)) }
        return parts.joined(separator: " · ")
    }

    private func row(_ task: TaskItem) -> some View {
        CalDayRow(task: task, selectedTask: $selectedTask)
    }
}

private struct CalDayRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.fontScale) private var fontScale
    @Bindable var task: TaskItem
    @Binding var selectedTask: TaskItem?
    @State private var showPopover = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button { toggle() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .alignedToFirstLine(scale: fontScale)

            Circle().fill(task.quadrant.color).frame(width: 8, height: 8)
                .alignedToFirstLine(scale: fontScale)

            VStack(alignment: .leading, spacing: 2) {
                TaggedTitleText(task: task,
                                strikethrough: task.isCompleted,
                                color: task.isCompleted ? .secondary : Color.appLabel)
                if !task.isCompleted { TaskMetaLine(task: task) }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { showPopover = true }
        .onTapGesture { selectedTask = task }
        .sheet(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    private func toggle() {
        task.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}
