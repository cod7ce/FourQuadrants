import SwiftUI
import SwiftData

struct QuadrantGridView: View {
    @Environment(\.modelContext) private var context
    @Binding var selectedTask: TaskItem?
    @Binding var weekStart: Date
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var newTask: TaskItem?

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
        .mainToolbar(week: weekStart, weekTasks: weekTasks) { newTask = makeTask() }
        .sheet(item: $newTask) { TaskEditor(task: $0, isNew: true) }
    }

    private func makeTask() -> TaskItem {
        let flags = Quadrant.urgentImportant.flags
        let t = TaskItem(isUrgent: flags.isUrgent, isImportant: flags.isImportant, weekStart: weekStart)
        context.insert(t)
        return t
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
                     weekStart: weekStart,
                     selectedTask: $selectedTask)
    }
}

// MARK: - 周头部：导航 + 本周完成进度

struct WeekHeaderBar: View {
    @Binding var weekStart: Date
    let tasks: [TaskItem]

    private var done: Int { tasks.filter(\.isCompleted).count }
    private var total: Int { tasks.count }
    /// 周标记：本周 → 高亮色文字；过去 → 橙色「回溯」；未来 → 不显示。
    @ViewBuilder private var weekMarkView: some View {
        if Week.isCurrent(weekStart) {
            Text(L("week.current")).foregroundStyle(Color.accentColor)
        } else if Week.isPast(weekStart) {
            Text(L("week.retro")).foregroundStyle(Color.orange)
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                navButton("chevron.left") { weekStart = Week.shift(weekStart, by: -1) }
                VStack(alignment: .center, spacing: 2) {
                    Text(Week.yearWeekLabel(weekStart)).appFont(.title3, weight: .bold)
                    HStack(spacing: 6) {
                        Text(Week.label(weekStart)).foregroundStyle(.secondary)
                        weekMarkView
                    }
                    .appFont(.caption)
                }
                navButton("chevron.right") { weekStart = Week.shift(weekStart, by: 1) }
            }

            Spacer()

            HStack(spacing: 10) {
                Text(L("overview.weekProgress")).appFont(.caption).foregroundStyle(.secondary)
                ThinProgressBar(ratio: total == 0 ? 0 : Double(done) / Double(total), color: .green)
                    .frame(width: 140)
                Text("\(done) / \(total)")
                    .appFont(.subheadline, weight: .semibold).monospacedDigit()
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

struct ThinProgressBar: View {
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
    @Environment(\.theme) private var theme
    let quadrant: Quadrant
    let tasks: [TaskItem]          // 该象限全部任务（含已完成）
    let weekStart: Date
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
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(active) { row($0, siblings: active) }
                    if !completed.isEmpty {
                        Text(String(format: L("grid.completedCount"), completed.count))
                            .appFont(.caption).foregroundStyle(.secondary)
                            .padding(.top, 2)
                        ForEach(completed) { row($0, siblings: completed) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .overlay(cardBorder)
        .dropDestination(for: TaskTransfer.self) { items, _ in
            for item in items {
                TaskMutations.schedule(uuid: item.taskUUID, to: quadrant, week: weekStart, in: context)
            }
            return !items.isEmpty
        } isTargeted: { isTargeted = $0 }
    }

    @ViewBuilder private var cardBackground: some View {
        if theme.cardStyle == .panel {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTargeted ? quadrant.color.opacity(0.12) : theme.surface)
                RoundedRectangle(cornerRadius: 2)
                    .fill(quadrant.color).frame(width: 3)
                    .padding(.vertical, 10)
            }
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(quadrant.color.opacity(isTargeted ? 0.18 : 0.08))
        }
    }

    @ViewBuilder private var cardBorder: some View {
        if theme.cardStyle == .panel {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? quadrant.color.opacity(0.7)
                              : theme.label.opacity(0.08), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(quadrant.color.opacity(isTargeted ? 0.7 : 0), lineWidth: 1.5)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: quadrant.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(quadrant.color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(quadrant.title).appFont(.headline).foregroundStyle(quadrant.color)
                Text(quadrant.actionHint).appFont(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(theme.cardStyle == .panel
                 ? "[\(completed.count)/\(tasks.count)]"
                 : "\(completed.count) / \(tasks.count)")
                .appFont(.subheadline, weight: .semibold, monospaced: theme.cardStyle == .panel)
                .monospacedDigit()
                .foregroundStyle(quadrant.color)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if theme.emptyState == .comment {
            Text("// \(L("grid.clean.title"))")
                .appFont(.callout, monospaced: true).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "sparkles").appFont(.title3).foregroundStyle(.secondary)
                Text(L("grid.clean.title")).appFont(.callout).foregroundStyle(.secondary)
                Text(L("grid.clean.subtitle")).appFont(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private func row(_ task: TaskItem, siblings: [TaskItem]) -> some View {
        OverviewTaskRow(task: task,
                        isSelected: selectedTask?.persistentModelID == task.persistentModelID,
                        siblings: siblings,
                        onSelect: { selectedTask = task })
            .draggable(TaskTransfer(taskUUID: task.taskUUID))
    }
}

// MARK: - 任务行（总览卡片内）

private struct OverviewTaskRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Environment(\.fontScale) private var fontScale
    @Bindable var task: TaskItem
    var isSelected: Bool = false
    var siblings: [TaskItem] = []
    var onSelect: () -> Void = {}
    @State private var showPopover = false
    @State private var dropTargeted = false

    static let checkboxWidth: CGFloat = 22
    static let gap: CGFloat = 9

    private var linkActive: Bool { optionHeld && !task.urls.isEmpty }
    private var subs: [TaskItem] { task.sortedSubtasks }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            parentRow
            // 父任务下列出子任务（未完成的父任务才展开，保持已完成区紧凑）
            if !task.isCompleted {
                // 子任务用更紧的行距，让树形竖干（├/└）连成一条线，不出现断点
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(subs.enumerated()), id: \.element.persistentModelID) { idx, sub in
                        OverviewSubtaskTree(sub: sub, guides: [], isLast: idx == subs.count - 1)
                    }
                }
            }
        }
        // 落放提示：整行淡高亮 = 嵌套为子任务；顶部细线 = 插到该任务前重排。
        .background {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                    .padding(.horizontal, -6).padding(.vertical, -3)
            }
        }
        .overlay(alignment: .top) {
            if dropTargeted {
                Capsule().fill(Color.accentColor).frame(height: 2).padding(.horizontal, -4).offset(y: -5)
            }
        }
        .dropDestination(for: TaskTransfer.self) { items, location in
            for it in items {
                if location.y < 12 {   // 顶部细条 → 重排到该任务前（可跨层级）
                    TaskMutations.reorder(draggedUUID: it.taskUUID, before: task, ordered: siblings, in: context)
                } else {               // 行主体 → 嵌套为该任务的子任务（含无子任务的父）
                    TaskMutations.makeChild(uuid: it.taskUUID, of: task, in: context)
                }
            }
            return !items.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }

    private var parentRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.gap) {
            completionToggle
                .alignedToFirstLine(scale: fontScale)
            VStack(alignment: .leading, spacing: 3) {
                TaggedTitleText(task: task,
                                strikethrough: task.isCompleted,
                                underline: linkActive,
                                color: linkActive ? .accentColor
                                    : (task.isCompleted ? .secondary : Color.appLabel))
                if !task.isCompleted { TaskMetaLine(task: task) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            DueDateLabel(task: task)
        }
        // 选中高亮：用外扩背景留出呼吸空间（不移动内容，保持子任务对齐）
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .padding(.horizontal, -8)
                .padding(.vertical, -5)
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
        .sheet(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    private var completionToggle: some View {
        Button { toggle() } label: {
            TaskCheckbox(isCompleted: task.isCompleted)
        }
        .buttonStyle(.plain)
        .frame(minWidth: Self.checkboxWidth)
    }

    private func toggle() {
        task.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}

/// 卡片里的子任务子树（递归，最深 3 层）：渲染自身一行，再递归渲染其子任务，
/// 每深一层多缩进一格；树线含各祖先列的延续竖线，保证多层下也连成完整树。
private struct OverviewSubtaskTree: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Environment(\.theme) private var theme
    @Bindable var sub: TaskItem
    /// 各祖先列是否还要继续画竖线（该祖先在其同级中还有后续项）。长度 = 本节点在子树中的层级。
    var guides: [Bool]
    var isLast: Bool = true
    @State private var showPopover = false
    @State private var dropTargeted = false

    // 每层缩进 = 一个父 checkbox 宽 + 间距，子任务 checkbox 对齐到上一层内容列
    static var indentStep: CGFloat { OverviewTaskRow.checkboxWidth + OverviewTaskRow.gap }
    private var leadingInset: CGFloat { CGFloat(guides.count + 1) * Self.indentStep }
    private var childSubs: [TaskItem] { sub.sortedSubtasks }
    private var linkActive: Bool { optionHeld && !sub.urls.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowView
            ForEach(Array(childSubs.enumerated()), id: \.element.persistentModelID) { idx, child in
                OverviewSubtaskTree(sub: child,
                                    guides: guides + [!isLast],
                                    isLast: idx == childSubs.count - 1)
            }
        }
    }

    private var rowView: some View {
        Group {
            if theme.subtask == .tree {
                // 树线作为 overlay：尺寸恒等于行内容（不会贪婪撑高），行距 0 下竖干跨行相接
                rowContent
                    .padding(.vertical, 3)
                    .padding(.leading, leadingInset)
                    .overlay(alignment: .topLeading) {
                        SubtaskTreeConnector(guides: guides, isLast: isLast,
                                             step: Self.indentStep,
                                             color: Color.appLabel.opacity(0.09))
                            .frame(width: leadingInset)
                    }
            } else {
                rowContent
                    .padding(.vertical, 3)
                    .padding(.leading, leadingInset)
            }
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .highPriorityGesture(
            TapGesture().modifiers(.option).onEnded {
                if let url = sub.urls.first { openURL(url) }
            }
        )
        #endif
        .onTapGesture(count: 2) { showPopover = true }
        .overlay(alignment: .top) {
            if dropTargeted {
                Capsule().fill(Color.accentColor).frame(height: 2).offset(y: -4)
            }
        }
        .draggable(TaskTransfer(taskUUID: sub.taskUUID))
        .dropDestination(for: TaskTransfer.self) { items, location in
            for it in items {
                if location.y < 10 {   // 顶部细条 → 插到该子任务前重排
                    TaskMutations.reorder(draggedUUID: it.taskUUID, before: sub,
                                          ordered: sub.parent?.sortedSubtasks ?? [], in: context)
                } else {               // 行主体 → 嵌套为该子任务的子任务（超深/成环由 makeChild 拦截）
                    TaskMutations.makeChild(uuid: it.taskUUID, of: sub, in: context)
                }
            }
            return !items.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .sheet(isPresented: $showPopover) { TaskEditor(task: sub) }
    }

    /// 行主体（勾选框 + 标题 + 截止日期），树线/缩进两种布局共用。
    private var rowContent: some View {
        HStack(alignment: .top, spacing: OverviewTaskRow.gap) {
            Button { toggle() } label: {
                TaskCheckbox(isCompleted: sub.isCompleted, size: 16)
            }
            .buttonStyle(.plain)
            Text(sub.title.isEmpty ? L("task.default.title") : sub.title)
                .appFont(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .strikethrough(sub.isCompleted)
                .underline(linkActive)
                .foregroundStyle(linkActive ? Color.accentColor
                                 : (sub.isCompleted ? .secondary : Color.appLabel))
            Spacer(minLength: 6)
            DueDateLabel(task: sub)
        }
    }

    private func toggle() {
        sub.toggleCompleted()
        try? context.save()
    }
}

/// 子任务树形连接线（矢量）：各祖先列的延续竖线 + 本节点的一条竖干 + 拐入 checkbox 的横线。
/// 作为行内容的 overlay 使用：高度恒等于行内容，行距 0 时竖干跨行相接。
private struct SubtaskTreeConnector: View {
    let guides: [Bool]      // 各祖先列是否继续画竖线
    let isLast: Bool
    let step: CGFloat
    let color: Color
    private let stem: CGFloat = 11       // 竖干在本列内的水平位置
    private let elbowY: CGFloat = 12     // 拐点高度（对齐首行 checkbox 中心）

    var body: some View {
        Canvas { ctx, size in
            // 祖先列：若该祖先还有后续同级，则本行内画一条贯通竖线
            for (i, draw) in guides.enumerated() where draw {
                let x = CGFloat(i) * step + stem
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(line, with: .color(color), lineWidth: 1.2)
            }
            // 本节点：竖干（末项到拐点即止，否则贯通）+ 拐入 checkbox 的横线
            let ownX = CGFloat(guides.count) * step + stem
            var trunk = Path()
            trunk.move(to: CGPoint(x: ownX, y: 0))
            trunk.addLine(to: CGPoint(x: ownX, y: isLast ? elbowY : size.height))
            var arm = Path()
            arm.move(to: CGPoint(x: ownX, y: elbowY))
            arm.addLine(to: CGPoint(x: size.width - 7, y: elbowY))   // 到 checkbox 前留出空隙
            ctx.stroke(trunk, with: .color(color), lineWidth: 1.2)
            ctx.stroke(arm, with: .color(color), lineWidth: 1.2)
        }
    }
}

#Preview {
    @Previewable @State var sel: TaskItem?
    @Previewable @State var week = Week.currentStart
    return NavigationStack { QuadrantGridView(selectedTask: $sel, weekStart: $week) }
        .modelContainer(previewContainer)
}
