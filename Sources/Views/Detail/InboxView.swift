import SwiftUI
import SwiftData

/// 收集箱底部条：三个主视图共用。折叠为一行（快速添加 + 提示）；
/// 展开为一排横向卡片，可拖到某天设日期、或拖到象限限定优先级。
struct InboxBar: View {
    let weekStart: Date
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @AppStorage("inboxExpanded") private var expanded = false
    @State private var quickAdd = ""

    /// 收集箱 = 没有截止日期的未完成顶层任务。
    private var items: [TaskItem] {
        allTasks.filter { $0.parent == nil && !$0.isCompleted && $0.dueDate == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            if expanded { expandedContent } else { collapsedBar }
        }
    }

    // MARK: - 折叠

    private var headerRow: some View {
        HStack(spacing: 12) {
            title
            Spacer(minLength: 8)
            Text(L("inbox.hint")).font(.caption).foregroundStyle(.tertiary)
            chevron
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var collapsedBar: some View { headerRow }

    // MARK: - 展开

    private var expandedContent: some View {
        VStack(spacing: 0) {
            headerRow
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickAddCard
                    ForEach(items) { card($0) }
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appFill.ignoresSafeArea(edges: .bottom))
        }
    }

    // MARK: - 部件

    private var title: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray").foregroundStyle(.secondary)
            Text(L("inbox.title")).font(.subheadline.weight(.semibold))
            Text(String(format: L("inbox.badge"), items.count))
                .font(.caption2).monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
            Image(systemName: expanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private var quickAddCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
            TextField(L("inbox.quickAdd"), text: $quickAdd)
                .textFieldStyle(.plain)
                .onSubmit(add)
        }
        .padding(10)
        .frame(width: 190, height: 74, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
    }

    private func card(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(task.quadrant.color).frame(width: 7, height: 7)
                ForEach(task.tagList) { TagChip(tag: $0) }
                Spacer(minLength: 0)
            }
            Text(task.title.isEmpty ? L("task.default.title") : task.title)
                .appFont(.callout).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 190, height: 74, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5))
        .draggable(TaskTransfer(taskUUID: task.taskUUID))
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
