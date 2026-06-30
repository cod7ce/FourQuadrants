import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.commandHeld) private var commandHeld
    @Bindable var task: TaskItem
    @State private var expanded = false
    @State private var showPopover = false

    private var linkActive: Bool { commandHeld && !task.urls.isEmpty }

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
                            .appFont(.body)
                            .strikethrough(task.isCompleted)
                            .underline(linkActive)
                            .foregroundStyle(linkActive ? Color.accentColor : (task.isCompleted ? .secondary : .primary))
                    }
                    metaLine
                    if !task.tagList.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(task.tagList) { TagChip(tag: $0) }
                        }
                    }
                }

                Spacer(minLength: 6)

                DueDateLabel(task: task)

                if !task.sortedSubtasks.isEmpty {
                    Button { withAnimation { expanded.toggle() } } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .appFont(.caption)
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
                            .appFont(.callout)
                            .strikethrough(sub.isCompleted)
                            .foregroundStyle(sub.isCompleted ? .secondary : .primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        #if os(macOS)
        .highPriorityGesture(
            TapGesture().modifiers(.command).onEnded {
                if let url = task.urls.first { openURL(url) }
            }
        )
        #endif
        .onTapGesture(count: 2) { showPopover = true }
        .popover(isPresented: $showPopover) { TaskEditor(task: task) }
    }

    @ViewBuilder
    private var metaLine: some View {
        let subs = task.sortedSubtasks
        HStack(spacing: 10) {
            if task.remindAt != nil { Image(systemName: "bell.fill") }
            if !task.urls.isEmpty { TaskLinksButton(urls: task.urls) }
            if !subs.isEmpty {
                Label("\(subs.filter(\.isCompleted).count)/\(subs.count)", systemImage: "checklist")
            }
        }
        .appFont(.caption2)
        .foregroundStyle(.secondary)
    }

    private func toggle(_ t: TaskItem) {
        t.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: t) }
    }
}
