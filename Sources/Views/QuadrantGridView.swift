import SwiftUI
import SwiftData

struct QuadrantGridView: View {
    @Binding var selectedTask: TaskItem?
    let weekStart: Date
    @AppStorage("showCompleted") private var showCompleted = false
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var showAdd = false

    private var tasks: [TaskItem] { allTasks.inWeek(weekStart) }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Quadrant.allCases) { q in
                    QuadrantCard(quadrant: q,
                                 tasks: tasks.inScope(.quadrant(q), showCompleted: showCompleted),
                                 selectedTask: $selectedTask)
                }
            }
            .padding()
        }
        .navigationTitle(L("overview.title"))
        .toolbar {
            ToolbarItem {
                Button { showAdd = true } label: { Label(L("action.create"), systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            QuickAddView(defaultQuadrant: .urgentImportant, weekStart: weekStart)
        }
    }
}

private struct QuadrantCard: View {
    @Environment(\.modelContext) private var context
    let quadrant: Quadrant
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: quadrant.symbol).foregroundStyle(quadrant.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(quadrant.title).font(.headline)
                    Text(quadrant.actionHint).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            Divider()
            if tasks.isEmpty {
                Text(L("grid.empty"))
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasks.prefix(6)) { task in
                    CompactTaskRow(task: task,
                                   isSelected: selectedTask?.persistentModelID == task.persistentModelID,
                                   onSelect: { selectedTask = task })
                        .draggable(TaskTransfer(taskUUID: task.taskUUID))
                }
                if tasks.count > 6 {
                    Text(String(format: L("grid.more"), tasks.count - 6))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: .infinity, alignment: .topLeading)
        .background(quadrant.color.opacity(isTargeted ? 0.20 : 0.07),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(quadrant.color.opacity(isTargeted ? 0.8 : 0.3)))
        .dropDestination(for: TaskTransfer.self) { items, _ in
            for item in items {
                TaskMutations.move(uuid: item.taskUUID, to: quadrant, in: context)
            }
            return !items.isEmpty
        } isTargeted: { isTargeted = $0 }
    }
}

private struct CompactTaskRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    var isSelected: Bool = false
    var onSelect: () -> Void = {}
    @State private var showPopover = false

    var body: some View {
        HStack(spacing: 6) {
            CompletionToggle(isCompleted: task.isCompleted) { toggle() }
            if let key = task.issueKey { IssueKeyBadge(key: key) }
            ForEach(task.tagList) { TagChip(tag: $0) }
            Text(task.title.isEmpty ? L("task.default.title") : task.title)
                .lineLimit(1)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
            Spacer(minLength: 6)
            DueDateLabel(task: task)
        }
        .font(.callout)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor.opacity(isSelected ? 0.6 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { showPopover = true }
        .onTapGesture { onSelect() }
        .popover(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    private func toggle() {
        task.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}

#Preview {
    @Previewable @State var sel: TaskItem?
    return NavigationStack { QuadrantGridView(selectedTask: $sel, weekStart: Week.currentStart) }
        .modelContainer(previewContainer)
}
