import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

enum SidebarItem: Hashable {
    case overview
    case thisWeek
    case calendar
    case tag(String)      // 按标签名，直接在侧边栏展开
}

extension Notification.Name {
    /// 菜单快捷键请求切换主视图（object 为目标 SidebarItem）。
    static let navigateSidebar = Notification.Name("navigateSidebar")
    /// 菜单快捷键请求打开笔记窗口。
    static let openNotes = Notification.Name("openNotes")
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(LocalizationConfig.storageKey) private var language = AppLanguage.zhHans.rawValue
    @AppStorage(FontScale.key) private var fontIndex = FontScale.defaultIndex
    @AppStorage(AppFontSetting.key) private var appFontName = ""
    #if os(macOS)
    @StateObject private var modifiers = ModifierWatcher()
    #endif

    private var optionHeld: Bool {
        #if os(macOS)
        modifiers.option
        #else
        false
        #endif
    }

    @State private var sidebar: SidebarItem? = .overview
    @State private var selectedTask: TaskItem?
    @State private var selectedWeek = Week.currentStart
    @AppStorage("notesWeekStamp") private var notesWeekStamp: Double = 0
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// 玻璃材质的「实心」程度：0 = 全玻璃，1 = 全实心。改这个数一步步看效果。
    static let glassTint: Double = 0.95
    #if os(iOS)
    @State private var showSettings = false
    #endif

    // 剪贴板感知
    @State private var clipboardCandidate: ParsedTaskInput?
    @State private var showClipboardPrompt = false
    @State private var lastClipboardChange = -1

    var body: some View {
        NavigationSplitView {
            #if os(iOS)
            SidebarView(selection: $sidebar, onSettings: { showSettings = true })
                .navigationTitle(L("app.title"))
            #else
            SidebarView(selection: $sidebar)
            #endif
        } detail: {
            // 收集箱作为底部条，三视图共用；笔记走标题栏悬浮弹窗。
            VStack(spacing: 0) {
                MainArea(sidebar: sidebar ?? .overview,
                         selectedTask: $selectedTask,
                         weekStart: $selectedWeek)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                InboxBar(weekStart: selectedWeek)
            }
            #if os(macOS)
            // 标题栏下方分隔线：仅在内容区（不含侧边栏）
            .overlay(alignment: .top) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 0.5)
            }
            #endif
        }
        #if os(macOS)
        // 玻璃材质背景。glassTint 为「实心」旋钮：0 = 全玻璃，1 = 全实心（一步步调它看效果）。
        .background {
            VisualEffectView()
                .overlay(Color(nsColor: .windowBackgroundColor).opacity(Self.glassTint))
                .ignoresSafeArea()
        }
        .background(WindowTranslucency())                   // 窗口非不透明，透出桌面
        #endif
        .foregroundStyle(Color.appLabel)                                 // 全局柔化主文本色
        .environment(\.locale, .app)
        .environment(\.optionHeld, optionHeld)                           // 按住 ⌥ 提示可点链接
        .environment(\.fontScale, FontScale.scale(fontIndex))            // ⌘+ / ⌘- 调整字号
        .environment(\.appFontName, appFontName)                         // 全局字体（设置里选）
        .environment(\.font, AppFont.font(.body, scale: FontScale.scale(fontIndex), name: appFontName))
        .id(language)   // 切换语言时整体重建，立即生效
        #if os(iOS)
        .sheet(isPresented: $showSettings) { SettingsView() }
        #endif
        .task { await checkClipboard() }
        // 把所选周共享给独立的笔记窗口
        .onChange(of: selectedWeek, initial: true) { _, w in
            notesWeekStamp = w.timeIntervalSinceReferenceDate
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateSidebar)) { note in
            if let item = note.object as? SidebarItem { sidebar = item }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .openNotes)) { _ in
            openWindow(id: "notes")
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkClipboard() } }
        }
        #if os(macOS)
        // macOS 上 scenePhase 在切回窗口时不一定触发；用应用激活通知兜底
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await checkClipboard() }
        }
        #endif
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
        if let name = parsed.tagName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            task.tags = [tag(named: name)]
        }
        try? context.save()
        clipboardCandidate = nil
    }

    /// 按名称取标签，没有就新建一个（用于规则自动打标签）。
    private func tag(named name: String) -> Tag {
        var descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }
        let count = (try? context.fetchCount(FetchDescriptor<Tag>())) ?? 0
        let t = Tag(name: name, colorHex: TagPalette.hexes[count % TagPalette.hexes.count])
        context.insert(t)
        return t
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
        NavigationStack {
            switch sidebar {
            case .overview:
                QuadrantGridView(selectedTask: $selectedTask, weekStart: $weekStart)
            case .thisWeek:
                WeekAgendaView(selectedTask: $selectedTask, weekStart: $weekStart)
            case .calendar:
                CalendarView(selectedTask: $selectedTask, weekStart: $weekStart)
            case .tag(let name):
                listArea(.tag(name))
            }
        }
    }

    private func listArea(_ scope: TaskScope) -> some View {
        VStack(spacing: 0) {
            WeekNavigatorBar(weekStart: $weekStart)
            Divider()
            TaskListView(scope: scope, selectedTask: $selectedTask, weekStart: weekStart)
        }
    }
}

/// 周导航：上一周 / 当前周范围 / 下一周，以及「回到本周」。
struct WeekNavigatorBar: View {
    @Binding var weekStart: Date

    /// 周标记：本周 → 高亮色文字；过去 → 橙色「回溯」；未来 → 不显示。
    @ViewBuilder private var weekMarkView: some View {
        if Week.isCurrent(weekStart) {
            Text(L("week.current")).foregroundStyle(Color.accentColor)
        } else if Week.isPast(weekStart) {
            Text(L("week.retro")).foregroundStyle(Color.orange)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            Button { weekStart = Week.shift(weekStart, by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            VStack(spacing: 2) {
                // 周信息为标题；日期范围 + 本周/回溯 为描述（未来周不加标记）
                Text(Week.yearWeekLabel(weekStart)).appFont(.headline)
                HStack(spacing: 6) {
                    Text(Week.label(weekStart))
                        .foregroundStyle(.secondary)
                    weekMarkView
                }
                .appFont(.caption)
            }
            .frame(minWidth: 180)

            Button { weekStart = Week.shift(weekStart, by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Spacer()
        }
        .overlay(alignment: .trailing) {
            if !Week.isCurrent(weekStart) {
                Button(L("action.thisWeek")) { weekStart = Week.currentStart }
                    .buttonStyle(.bordered)
                    .padding(.trailing, 12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
