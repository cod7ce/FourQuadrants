import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    let scope: TaskScope
    @Binding var selectedTask: TaskItem?
    let weekStart: Date

    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var search = ""
    @State private var showAdd = false

    private var tasks: [TaskItem] {
        let base = allTasks.inWeek(weekStart).inScope(scope, showCompleted: true)
        guard !search.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(search)
            || ($0.issueKey?.localizedCaseInsensitiveContains(search) ?? false)
            || $0.tagList.contains { $0.name.localizedCaseInsensitiveContains(search) }
        }
    }

    private var defaultQuadrant: Quadrant {
        if case .quadrant(let q) = scope { return q }
        return .urgentImportant
    }

    private var emptyText: String { search.isEmpty ? L("list.empty") : L("list.noMatch") }
    private func completeText(_ done: Bool) -> String { done ? L("action.incomplete") : L("action.complete") }

    var body: some View {
        List(selection: $selectedTask) {
            ForEach(tasks) { task in
                TaskRowView(task: task)
                    .tag(task)
                    .draggable(TaskTransfer(taskUUID: task.taskUUID))
                    .swipeActions(edge: .leading) {
                        Button { toggle(task) } label: {
                            Label(completeText(task.isCompleted),
                                  systemImage: "checkmark.circle")
                        }.tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete(task) } label: {
                            Label(L("action.delete"), systemImage: "trash")
                        }
                        Button { task.isUrgent.toggle(); save(task) } label: {
                            Label(L("action.urgent"), systemImage: "bolt.fill")
                        }.tint(.orange)
                    }
            }
            .onMove(perform: reorder)
        }
        .navigationTitle(scope.title)
        .searchable(text: $search, prompt: L("list.search.prompt"))
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView(emptyText, systemImage: scope.symbol)
            }
        }
        .toolbar {
            ToolbarItem {
                Button { showAdd = true } label: { Label(L("action.create"), systemImage: "plus") }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            #endif
        }
        .sheet(isPresented: $showAdd) {
            QuickAddView(defaultQuadrant: defaultQuadrant, weekStart: weekStart)
        }
        .dropDestination(for: TaskTransfer.self) { items, _ in
            guard case .quadrant(let q) = scope else { return false }
            for item in items { TaskMutations.move(uuid: item.taskUUID, to: q, in: context) }
            return !items.isEmpty
        }
    }

    private func toggle(_ task: TaskItem) {
        task.toggleCompleted()
        save(task)
    }

    private func delete(_ task: TaskItem) {
        NotificationManager.shared.cancel(for: task)
        if selectedTask == task { selectedTask = nil }
        context.delete(task)
        try? context.save()
    }

    private func save(_ task: TaskItem) {
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }

    private func reorder(from: IndexSet, to: Int) {
        var arr = tasks
        arr.move(fromOffsets: from, toOffset: to)
        for (i, t) in arr.enumerated() { t.sortOrder = Double(i) }
        try? context.save()
    }
}

#Preview {
    @Previewable @State var sel: TaskItem?
    return NavigationStack {
        TaskListView(scope: .quadrant(.urgentImportant), selectedTask: $sel, weekStart: Week.currentStart)
    }
    .modelContainer(previewContainer)
}
