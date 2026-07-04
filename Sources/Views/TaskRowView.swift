import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Bindable var task: TaskItem
    @State private var expanded = true      // 列表里子任务默认展开
    @State private var showPopover = false

    private var linkActive: Bool { optionHeld && !task.urls.isEmpty }

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
                    SubtaskEditableRow(sub: sub)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        #if os(macOS)
        .highPriorityGesture(
            TapGesture().modifiers(.option).onEnded {
                if let url = task.urls.first { openURL(url) }
            }
        )
        #endif
        .onTapGesture(count: 2) { showPopover = true }
        .sheet(isPresented: $showPopover) { TaskEditor(task: task) }
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

/// 列表里的子任务行：可勾选，双击打开编辑器配置。
private struct SubtaskEditableRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.optionHeld) private var optionHeld
    @Bindable var sub: TaskItem
    @State private var showPopover = false
    @State private var dropTargeted = false

    private var linkActive: Bool { optionHeld && !sub.urls.isEmpty }

    var body: some View {
        HStack(spacing: 8) {
            CompletionToggle(isCompleted: sub.isCompleted) { toggle() }
            Text(sub.title)
                .appFont(.callout)
                .strikethrough(sub.isCompleted)
                .underline(linkActive)
                .foregroundStyle(linkActive ? Color.accentColor : (sub.isCompleted ? .secondary : .primary))
            Spacer(minLength: 6)
            DueDateLabel(task: sub)
        }
        .padding(.leading, 28)
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
                Capsule().fill(Color.accentColor).frame(height: 2).offset(y: -3)
            }
        }
        .draggable(TaskTransfer(taskUUID: sub.taskUUID))
        .dropDestination(for: TaskTransfer.self) { items, _ in
            for it in items {
                TaskMutations.reorder(draggedUUID: it.taskUUID, before: sub,
                                      ordered: sub.parent?.sortedSubtasks ?? [], in: context)
            }
            return !items.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .sheet(isPresented: $showPopover) { TaskEditor(task: sub) }
    }

    private func toggle() {
        sub.toggleCompleted()
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: sub) }
    }
}
