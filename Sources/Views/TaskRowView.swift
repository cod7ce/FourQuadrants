import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CompletionToggle(isCompleted: task.isCompleted) { toggle(task) }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let key = task.issueKey {
                            IssueKeyBadge(key: key, url: task.urls.first)
                        }
                        Text(task.title.isEmpty ? L("task.default.title") : task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    }
                    metaLine
                    if !task.tagList.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(task.tagList) { TagChip(tag: $0) }
                        }
                    }
                }

                Spacer(minLength: 0)

                if !task.sortedSubtasks.isEmpty {
                    Button { withAnimation { expanded.toggle() } } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if expanded {
                ForEach(task.sortedSubtasks) { sub in
                    HStack(spacing: 8) {
                        CompletionToggle(isCompleted: sub.isCompleted) { toggle(sub) }
                        Text(sub.title)
                            .font(.callout)
                            .strikethrough(sub.isCompleted)
                            .foregroundStyle(sub.isCompleted ? .secondary : .primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var metaLine: some View {
        let subs = task.sortedSubtasks
        HStack(spacing: 10) {
            if let due = task.dueDate {
                Label(due.formatted(.dateTime.month().day().locale(.app)),
                      systemImage: "calendar")
                    .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
            }
            if task.remindAt != nil { Image(systemName: "bell.fill") }
            if !task.urls.isEmpty { TaskLinksButton(urls: task.urls) }
            if !subs.isEmpty {
                Label("\(subs.filter(\.isCompleted).count)/\(subs.count)", systemImage: "checklist")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func toggle(_ t: TaskItem) {
        t.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: t) }
    }
}
