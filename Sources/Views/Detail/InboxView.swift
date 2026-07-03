import SwiftUI
import SwiftData

/// 待安排 Inbox：列出所有未完成的顶层任务，拖到某周的象限即可安排。
struct InboxView: View {
    let weekStart: Date
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @State private var quickAdd = ""

    private var items: [TaskItem] { allTasks.filter { $0.parent == nil && !$0.isCompleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("inbox.subtitle"))
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.bottom, 12)

            quickAddRow
                .padding(.horizontal, 16).padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { row($0) }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
            }

            Divider()
            Text(String(format: L("inbox.count"), items.count))
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private var quickAddRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").foregroundStyle(.secondary)
            TextField(L("inbox.quickAdd"), text: $quickAdd)
                .textFieldStyle(.plain)
                .onSubmit(add)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(task.quadrant.color).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title.isEmpty ? L("task.default.title") : task.title)
                        .appFont(.body).lineLimit(1)
                    ForEach(task.tagList) { TagChip(tag: $0) }
                }
                Text(subtitle(task)).appFont(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .contentShape(Rectangle())
        .draggable(TaskTransfer(taskUUID: task.taskUUID))
    }

    private func subtitle(_ task: TaskItem) -> String {
        let wk = Week.isCurrent(task.weekStart)
            ? L("week.current.short")
            : String(format: L("inbox.week"), Week.calendar.component(.weekOfYear, from: task.weekStart))
        return "\(wk) · \(task.quadrant.title)"
    }

    private func add() {
        let title = quickAdd.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let flags = Quadrant.urgentImportant.flags
        let t = TaskItem(title: title, isUrgent: flags.isUrgent,
                         isImportant: flags.isImportant, weekStart: weekStart)
        context.insert(t)
        try? context.save()
        quickAdd = ""
    }
}
