import SwiftUI
import SwiftData

struct QuadrantGridView: View {
    @Binding var selectedTask: TaskItem?
    @Binding var weekStart: Date
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var showAdd = false

    private var weekTasks: [TaskItem] { allTasks.inWeek(weekStart).topLevel }

    var body: some View {
        VStack(spacing: 0) {
            WeekHeaderBar(weekStart: $weekStart, tasks: weekTasks)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)

            ScrollView {
                // 手动 2×2：每张卡片 maxWidth:.infinity，保证左右两列等宽并让长标题截断
                VStack(spacing: 16) {
                    gridRow(.urgentImportant, .important)
                    gridRow(.urgent, .neither)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(L("overview.title"))
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                Menu {
                    Button(L("menu.exportMd.file")) {
                        MarkdownExporter.exportToFile(weekStart: weekStart, weekTasks: weekTasks)
                    }
                    Button(L("menu.exportMd.clipboard")) {
                        MarkdownExporter.copyToPasteboard(weekStart: weekStart, weekTasks: weekTasks)
                    }
                } label: {
                    Label(L("menu.exportMd"), systemImage: "square.and.arrow.up")
                }
            }
            #endif
            ToolbarItem {
                Button { showAdd = true } label: { Label(L("action.create"), systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            QuickAddView(defaultQuadrant: .urgentImportant, weekStart: weekStart)
        }
    }

    private func gridRow(_ a: Quadrant, _ b: Quadrant) -> some View {
        HStack(alignment: .top, spacing: 16) {
            card(a)
            card(b)
        }
    }

    private func card(_ q: Quadrant) -> some View {
        QuadrantCard(quadrant: q,
                     tasks: weekTasks.filter { $0.quadrant == q },
                     selectedTask: $selectedTask)
    }
}

// MARK: - 周头部：导航 + 本周完成进度

private struct WeekHeaderBar: View {
    @Binding var weekStart: Date
    let tasks: [TaskItem]

    private var done: Int { tasks.filter(\.isCompleted).count }
    private var total: Int { tasks.count }
    private var mark: String { Week.isCurrent(weekStart) ? L("week.current") : L("week.retro") }

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                navButton("chevron.left") { weekStart = Week.shift(weekStart, by: -1) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Week.yearWeekLabel(weekStart)).font(.title3.bold())
                    HStack(spacing: 6) {
                        Text(Week.label(weekStart))
                        Text(mark).foregroundStyle(Week.isCurrent(weekStart) ? .secondary : Color.orange)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                navButton("chevron.right") { weekStart = Week.shift(weekStart, by: 1) }
            }

            Spacer()

            HStack(spacing: 10) {
                Text(L("overview.weekProgress")).font(.caption).foregroundStyle(.secondary)
                ThinProgressBar(ratio: total == 0 ? 0 : Double(done) / Double(total), color: .green)
                    .frame(width: 140)
                Text("\(done) / \(total)")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct ThinProgressBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, ratio)) * geo.size.width)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - 象限卡片

private struct QuadrantCard: View {
    @Environment(\.modelContext) private var context
    let quadrant: Quadrant
    let tasks: [TaskItem]          // 该象限全部任务（含已完成）
    @Binding var selectedTask: TaskItem?
    @State private var isTargeted = false

    private var active: [TaskItem] { tasks.filter { !$0.isCompleted } }
    private var completed: [TaskItem] { tasks.filter(\.isCompleted) }
    private var ratio: Double { tasks.isEmpty ? 0 : Double(completed.count) / Double(tasks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if tasks.isEmpty {
                emptyState
            } else {
                ThinProgressBar(ratio: ratio, color: quadrant.color)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(active) { row($0, completed: false) }
                    if !completed.isEmpty {
                        Text(String(format: L("grid.completedCount"), completed.count))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 2)
                        ForEach(completed) { row($0, completed: true) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .topLeading)
        .background(quadrant.color.opacity(isTargeted ? 0.18 : 0.08),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(quadrant.color.opacity(isTargeted ? 0.7 : 0), lineWidth: 1.5)
        )
        .dropDestination(for: TaskTransfer.self) { items, _ in
            for item in items { TaskMutations.move(uuid: item.taskUUID, to: quadrant, in: context) }
            return !items.isEmpty
        } isTargeted: { isTargeted = $0 }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: quadrant.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(quadrant.color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(quadrant.title).font(.headline).foregroundStyle(quadrant.color)
                Text(quadrant.actionHint).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(completed.count) / \(tasks.count)")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(quadrant.color)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles").font(.title3).foregroundStyle(.secondary)
            Text(L("grid.clean.title")).font(.callout).foregroundStyle(.secondary)
            Text(L("grid.clean.subtitle")).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func row(_ task: TaskItem, completed: Bool) -> some View {
        OverviewTaskRow(task: task,
                        isSelected: selectedTask?.persistentModelID == task.persistentModelID,
                        onSelect: { selectedTask = task })
            .draggable(TaskTransfer(taskUUID: task.taskUUID))
    }
}

// MARK: - 任务行（总览卡片内）

private struct OverviewTaskRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Bindable var task: TaskItem
    var isSelected: Bool = false
    var onSelect: () -> Void = {}
    @State private var showPopover = false

    static let checkboxWidth: CGFloat = 22
    static let gap: CGFloat = 9

    private var linkActive: Bool { optionHeld && !task.urls.isEmpty }
    private var subs: [TaskItem] { task.sortedSubtasks }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            parentRow
            // 父任务下列出子任务（未完成的父任务才展开，保持已完成区紧凑）
            if !task.isCompleted {
                ForEach(subs) { sub in OverviewSubtaskRow(sub: sub) }
            }
        }
    }

    private var parentRow: some View {
        HStack(alignment: .top, spacing: Self.gap) {
            completionToggle
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title.isEmpty ? L("task.default.title") : task.title)
                    .appFont(.body)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted)
                    .underline(linkActive)
                    .foregroundStyle(linkActive ? Color.accentColor
                                     : (task.isCompleted ? .secondary : .primary))
                if !task.isCompleted { metaLine }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            DueDateLabel(task: task)
        }
        .padding(.vertical, 1)
        .background(isSelected ? Color.accentColor.opacity(0.14) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
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
        .popover(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    private var completionToggle: some View {
        Button { toggle() } label: {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(task.isCompleted ? Color.green : Color.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .frame(width: Self.checkboxWidth)
    }

    @ViewBuilder
    private var metaLine: some View {
        let hasKey = !(task.issueKey ?? "").isEmpty
        if hasKey || !task.tagList.isEmpty || !subs.isEmpty {
            HStack(spacing: 5) {
                if let key = task.issueKey, !key.isEmpty { Text(key) }
                if !task.tagList.isEmpty {
                    if hasKey { Text("·") }
                    ForEach(task.tagList) { TagChip(tag: $0) }
                }
                if !subs.isEmpty {
                    Text("·")
                    Text("\(subs.filter(\.isCompleted).count)/\(subs.count)")
                }
            }
            .appFont(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func toggle() {
        task.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}

/// 卡片里的子任务行：checkbox 错开一个父 checkbox，对齐到父任务内容列；
/// 可勾选、双击编辑、⌥ 点链接、显示截止日期。
private struct OverviewSubtaskRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Bindable var sub: TaskItem
    @State private var showPopover = false

    private var linkActive: Bool { optionHeld && !sub.urls.isEmpty }

    var body: some View {
        HStack(spacing: OverviewTaskRow.gap) {
            Button { toggle() } label: {
                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                    .imageScale(.medium)
                    .foregroundStyle(sub.isCompleted ? Color.green : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            Text(sub.title.isEmpty ? L("task.default.title") : sub.title)
                .appFont(.callout)
                .lineLimit(1)
                .strikethrough(sub.isCompleted)
                .underline(linkActive)
                .foregroundStyle(linkActive ? Color.accentColor
                                 : (sub.isCompleted ? .secondary : .primary))
            Spacer(minLength: 6)
            DueDateLabel(task: sub)
        }
        .padding(.leading, OverviewTaskRow.checkboxWidth + OverviewTaskRow.gap)
        .contentShape(Rectangle())
        #if os(macOS)
        .highPriorityGesture(
            TapGesture().modifiers(.option).onEnded {
                if let url = sub.urls.first { openURL(url) }
            }
        )
        #endif
        .onTapGesture(count: 2) { showPopover = true }
        .popover(isPresented: $showPopover) { TaskEditor(task: sub) }
    }

    private func toggle() {
        sub.toggleCompleted()
        try? context.save()
    }
}

#Preview {
    @Previewable @State var sel: TaskItem?
    @Previewable @State var week = Week.currentStart
    return NavigationStack { QuadrantGridView(selectedTask: $sel, weekStart: $week) }
        .modelContainer(previewContainer)
}
