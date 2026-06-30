import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case overview
    case scope(TaskScope)
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(LocalizationConfig.storageKey) private var language = AppLanguage.zhHans.rawValue
    @AppStorage(FontScale.key) private var fontIndex = FontScale.defaultIndex
    #if os(macOS)
    @StateObject private var modifiers = ModifierWatcher()
    #endif

    private var commandHeld: Bool {
        #if os(macOS)
        modifiers.command
        #else
        false
        #endif
    }

    @State private var sidebar: SidebarItem? = .overview
    @State private var selectedTask: TaskItem?
    @State private var selectedWeek = Week.currentStart
    #if os(iOS)
    @State private var showSettings = false
    #endif

    // 剪贴板感知
    @State private var clipboardCandidate: ParsedTaskInput?
    @State private var showClipboardPrompt = false
    @State private var lastClipboardChange = -1

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebar, weekStart: selectedWeek)
                .navigationTitle(L("app.title"))
                #if os(iOS)
                .toolbar {
                    ToolbarItem {
                        Button { showSettings = true } label: {
                            Label(L("settings.title"), systemImage: "gearshape")
                        }
                    }
                }
                #endif
        } detail: {
            MainArea(sidebar: sidebar ?? .overview,
                     selectedTask: $selectedTask,
                     weekStart: $selectedWeek)
        }
        .environment(\.locale, .app)
        .environment(\.commandHeld, commandHeld)                         // 按住 ⌘ 提示可点链接
        .environment(\.fontScale, FontScale.scale(fontIndex))            // ⌘+ / ⌘- 调整字号
        .environment(\.font, AppFont.font(.body, scale: FontScale.scale(fontIndex)))
        .id(language)   // 切换语言时整体重建，立即生效
        #if os(iOS)
        .sheet(isPresented: $showSettings) { SettingsView() }
        #endif
        .task { await checkClipboard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkClipboard() } }
        }
        .confirmationDialog(
            L("clipboard.prompt.title"),
            isPresented: $showClipboardPrompt,
            titleVisibility: .visible,
            presenting: clipboardCandidate
        ) { parsed in
            ForEach(Quadrant.allCases) { q in
                Button(q.title) { add(parsed, to: q) }
            }
            Button(L("action.cancel"), role: .cancel) { clipboardCandidate = nil }
        } message: { parsed in
            Text(previewText(parsed))
        }
    }

    private func checkClipboard() async {
        guard let (parsed, change) = await ClipboardReader.candidate(since: lastClipboardChange) else { return }
        lastClipboardChange = change
        clipboardCandidate = parsed
        showClipboardPrompt = true
    }

    private func add(_ parsed: ParsedTaskInput, to quadrant: Quadrant) {
        let flags = quadrant.flags
        let title = parsed.title.isEmpty
            ? (parsed.issueKey ?? parsed.links.first ?? L("task.default.title"))
            : parsed.title
        let task = TaskItem(title: title,
                            isUrgent: flags.isUrgent,
                            isImportant: flags.isImportant,
                            links: parsed.links,
                            issueKey: parsed.issueKey,
                            weekStart: selectedWeek)
        context.insert(task)
        try? context.save()
        clipboardCandidate = nil
    }

    private func previewText(_ p: ParsedTaskInput) -> String {
        var parts: [String] = []
        if let k = p.issueKey { parts.append("\(L("clipboard.issuePrefix")) \(k)") }
        if !p.title.isEmpty { parts.append(p.title) }
        if let link = p.links.first { parts.append(link) }
        return parts.joined(separator: "\n")
    }
}

private struct MainArea: View {
    let sidebar: SidebarItem
    @Binding var selectedTask: TaskItem?
    @Binding var weekStart: Date

    var body: some View {
        VStack(spacing: 0) {
            WeekNavigatorBar(weekStart: $weekStart)
            Divider()
            NavigationStack {
                switch sidebar {
                case .overview:
                    QuadrantGridView(selectedTask: $selectedTask, weekStart: weekStart)
                case .scope(let scope):
                    TaskListView(scope: scope, selectedTask: $selectedTask, weekStart: weekStart)
                }
            }
        }
    }
}

/// 周导航：上一周 / 当前周范围 / 下一周，以及「回到本周」。
struct WeekNavigatorBar: View {
    @Binding var weekStart: Date

    private var weekMark: String {
        Week.isCurrent(weekStart) ? L("week.current") : L("week.retro")
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { weekStart = Week.shift(weekStart, by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            VStack(spacing: 2) {
                Text(Week.label(weekStart)).appFont(.headline)
                HStack(spacing: 6) {
                    Text(Week.yearWeekLabel(weekStart))
                    Text(weekMark)
                        .foregroundStyle(Week.isCurrent(weekStart) ? .secondary : Color.orange)
                }
                .appFont(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 180)

            Button { weekStart = Week.shift(weekStart, by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            if !Week.isCurrent(weekStart) {
                Button(L("action.thisWeek")) { weekStart = Week.currentStart }
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
