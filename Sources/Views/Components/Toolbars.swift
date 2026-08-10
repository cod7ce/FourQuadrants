import SwiftUI
import SwiftData

/// 标题栏工具组（总览 / 本周）：整理 · 分享 · 笔记 → 分隔线 → 主色实心「+」。
struct MainToolbar: ViewModifier {
    let week: Date
    let weekTasks: [TaskItem]
    let onAdd: () -> Void
    @Environment(\.openWindow) private var openWindow
    @State private var showCarry = false
    @State private var showExport = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        ToolIconButton(icon: .carry, help: L("carry.help")) { showCarry = true }
                        ToolIconButton(icon: .share, help: L("menu.exportMd")) { showExport = true }
                        ToolIconButton(icon: .notes, help: L("notes.title")) { openWindow(id: "notes") }
                        ToolbarDivider().padding(.horizontal, -1)
                        NewTaskButton(action: onAdd)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .sheet(isPresented: $showCarry) { CarryForwardSheet(week: week) }
            .confirmationDialog(L("menu.exportMd"), isPresented: $showExport, titleVisibility: .visible) {
                Button(L("menu.exportMd.file")) {
                    MarkdownExporter.exportToFile(weekStart: week, weekTasks: weekTasks)
                }
                Button(L("menu.exportMd.clipboard")) {
                    MarkdownExporter.copyToPasteboard(weekStart: week, weekTasks: weekTasks)
                }
                Button(L("action.cancel"), role: .cancel) {}
            }
    }
}

extension View {
    func mainToolbar(week: Date, weekTasks: [TaskItem], onAdd: @escaping () -> Void) -> some View {
        modifier(MainToolbar(week: week, weekTasks: weekTasks, onAdd: onAdd))
    }
}

/// 标题栏工具组（日历 / 列表）：笔记 → 分隔线 → 主色实心「+」。
struct NotesToolbar: ViewModifier {
    let onAdd: () -> Void
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 10) {
                    #if os(macOS)
                    ToolIconButton(icon: .notes, help: L("notes.title")) { openWindow(id: "notes") }
                    ToolbarDivider().padding(.horizontal, -1)
                    #endif
                    NewTaskButton(action: onAdd)
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

extension View {
    func notesToolbar(onAdd: @escaping () -> Void) -> some View { modifier(NotesToolbar(onAdd: onAdd)) }
}

/// 顶部工具图标按钮：图标居中于 32pt 可点区域，hover 淡底反馈。
struct ToolIconButton: View {
    let icon: AppIcon
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            AppIconView(icon: icon, size: 18)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(hovering ? Color.secondary.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// 顶栏细竖分隔线（工具与「+」之间分组）。
struct ToolbarDivider: View {
    var body: some View {
        Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1, height: 16)
    }
}

/// 新建任务：主色实心圆角按钮。
struct NewTaskButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            AppIconView(icon: .new, size: 13)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                .frame(width: 34, height: 34)      // 更大点击区
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("action.create"))
    }
}

/// 整理未完成：按来源周分组列出历史未完成任务，勾选后整理到目标周（默认全选）。
private struct CarryForwardSheet: View {
    let week: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var selected: Set<String> = []
    @State private var didInit = false

    // MARK: 数据

    private var sources: [TaskItem] {
        let target = Week.start(of: week)
        return allTasks.filter {
            $0.parent == nil && !$0.isCompleted && Week.start(of: $0.weekStart) < target
        }
    }
    private func list(_ action: TaskMutations.CarryAction) -> [TaskItem] {
        sources.filter { TaskMutations.carryAction(for: $0) == action }
            .sorted { $0.quadrant.rawValue < $1.quadrant.rawValue }
    }
    private var allSelected: Bool { !sources.isEmpty && selected.count == sources.count }
    private func selCount(_ action: TaskMutations.CarryAction) -> Int {
        list(action).filter { selected.contains($0.taskUUID) }.count
    }

    private var targetLabel: String {
        Week.isCurrent(week) ? L("week.current") : weekShort(week)
    }
    private func weekShort(_ d: Date) -> String {
        String(format: L("carry.weekShort"), Week.calendar.component(.weekOfYear, from: d))
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if sources.isEmpty {
                ContentUnavailableView(L("carry.empty"), systemImage: "tray")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        section(.move, "arrow.right", .blue,
                                String(format: L("carry.move.name"), targetLabel), L("carry.move.desc"))
                        section(.copyParent, "doc.on.doc", .green,
                                String(format: L("carry.copy.name"), targetLabel), L("carry.copy.desc"))
                        section(.complete, "checkmark", .orange,
                                L("carry.complete.name"), L("carry.complete.desc"))
                    }
                    .padding(20)
                }
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 640)
        .onAppear { if !didInit { selected = Set(sources.map(\.taskUUID)); didInit = true } }
    }

    // MARK: 头部（周切换）

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down").foregroundStyle(.secondary)
                Text(String(format: L("carry.header"), targetLabel)).appFont(.title2, weight: .bold)
            }
            HStack(spacing: 8) {
                weekChip(sourceLabel, tint: .secondary)
                Image(systemName: "chevron.right").imageScale(.small).foregroundStyle(.secondary)
                weekChip(targetChipLabel, tint: .green)
                Text(String(format: L("carry.remaining"), sources.count))
                    .appFont(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private var sourceLabel: String {
        let weeks = Set(sources.map { Week.start(of: $0.weekStart) })
        return weeks.count == 1 ? weekShort(weeks.first!) : L("carry.earlier")
    }
    private var targetChipLabel: String {
        weekShort(week) + (Week.isCurrent(week) ? " · " + L("week.current") : "")
    }
    private func weekChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .appFont(.caption)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint == .secondary ? Color.secondary : tint)
    }

    // MARK: 动作分区

    @ViewBuilder
    private func section(_ action: TaskMutations.CarryAction, _ icon: String, _ color: Color,
                         _ name: String, _ desc: String) -> some View {
        let items = list(action)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .appFont(.subheadline, weight: .semibold).foregroundStyle(color)
                        .frame(width: 26, height: 26)
                        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                    Text(name).appFont(.body, weight: .semibold)
                    Text("· " + desc).appFont(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Text("\(items.count)").appFont(.caption).foregroundStyle(.tertiary)
                }
                ForEach(items) { row($0) }
            }
        }
    }

    private func row(_ t: TaskItem) -> some View {
        let on = selected.contains(t.taskUUID)
        let subs = t.sortedSubtasks.filter { !$0.isCompleted }.count
        return Button {
            if on { selected.remove(t.taskUUID) } else { selected.insert(t.taskUUID) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(on ? Color.green : Color.secondary.opacity(0.5))
                Circle().fill(t.quadrant.color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.title.isEmpty ? L("task.default.title") : t.title)
                        .appFont(.body).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(t.quadrant.title)
                        ForEach(t.tagList) { Text("· \($0.name)") }
                        if subs > 0 {
                            Text(String(format: L("carry.subCount"), subs))
                                .appFont(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    .appFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 底部

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                selected = allSelected ? [] : Set(sources.map(\.taskUUID))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allSelected ? Color.green : .secondary)
                    Text(L("carry.selectAll"))
                }
            }
            .buttonStyle(.plain)
            .disabled(sources.isEmpty)

            Spacer()

            Text(breakdown).appFont(.caption).foregroundStyle(.secondary)

            Button(L("action.cancel")) { dismiss() }
            Button(String(format: L("carry.button"), selected.count, targetLabel)) {
                let picked = sources.filter { selected.contains($0.taskUUID) }
                TaskMutations.carryForward(picked, into: week, in: context)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(selected.isEmpty)
        }
        .padding(20)
    }

    private var breakdown: String {
        var parts: [String] = []
        let m = selCount(.move), c = selCount(.copyParent), d = selCount(.complete)
        if m > 0 { parts.append("\(m) " + L("carry.word.move")) }
        if c > 0 { parts.append("\(c) " + L("carry.word.copy")) }
        if d > 0 { parts.append("\(d) " + L("carry.word.done")) }
        let head = String(format: L("carry.selectedCount"), selected.count)
        return parts.isEmpty ? head : head + " · " + parts.joined(separator: " / ")
    }
}
