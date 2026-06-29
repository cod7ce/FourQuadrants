import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case overview
    case scope(TaskScope)
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var sidebar: SidebarItem? = .overview
    @State private var selectedTask: TaskItem?

    // 剪贴板感知
    @State private var clipboardCandidate: ParsedTaskInput?
    @State private var showClipboardPrompt = false
    @State private var lastClipboardChange = -1

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebar)
                .navigationTitle("四象限")
        } detail: {
            // 上下结构：上方为象限网格/列表，下方为所选任务详情。
            MainArea(sidebar: sidebar ?? .overview, selectedTask: $selectedTask)
        }
        .task { await checkClipboard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkClipboard() } }
        }
        .confirmationDialog(
            "检测到剪贴板内容，添加到哪个象限？",
            isPresented: $showClipboardPrompt,
            titleVisibility: .visible,
            presenting: clipboardCandidate
        ) { parsed in
            ForEach(Quadrant.allCases) { q in
                Button(q.title) { add(parsed, to: q) }
            }
            Button("取消", role: .cancel) { clipboardCandidate = nil }
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
            ? (parsed.issueKey ?? parsed.links.first ?? "新任务")
            : parsed.title
        let task = TaskItem(title: title,
                            isUrgent: flags.isUrgent,
                            isImportant: flags.isImportant,
                            links: parsed.links,
                            issueKey: parsed.issueKey)
        context.insert(task)
        try? context.save()
        clipboardCandidate = nil
    }

    private func previewText(_ p: ParsedTaskInput) -> String {
        var parts: [String] = []
        if let k = p.issueKey { parts.append("工单 \(k)") }
        if !p.title.isEmpty { parts.append(p.title) }
        if let link = p.links.first { parts.append(link) }
        return parts.joined(separator: "\n")
    }
}

private struct MainArea: View {
    let sidebar: SidebarItem
    @Binding var selectedTask: TaskItem?

    var body: some View {
        #if os(macOS)
        // VSplitView 不会自动撑满，必须显式 maxWidth/maxHeight 才能填满 detail 区域。
        VSplitView {
            top
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 240)
            bottom
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        VStack(spacing: 0) {
            top
            Divider()
            bottom
        }
        #endif
    }

    // 上：象限总览或某个范围的列表
    @ViewBuilder private var top: some View {
        NavigationStack {
            switch sidebar {
            case .overview:
                QuadrantGridView(selectedTask: $selectedTask)
            case .scope(let scope):
                TaskListView(scope: scope, selectedTask: $selectedTask)
            }
        }
    }

    // 下：所选任务的详情
    @ViewBuilder private var bottom: some View {
        NavigationStack {
            if let task = selectedTask {
                TaskDetailView(task: task)
            } else {
                ContentUnavailableView("选择一个任务查看详情",
                                       systemImage: "square.grid.2x2")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
