import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case overview
    case scope(TaskScope)
}

struct ContentView: View {
    @State private var sidebar: SidebarItem? = .overview
    @State private var selectedTask: TaskItem?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebar)
                .navigationTitle("四象限")
        } detail: {
            // 上下结构：上方为象限网格/列表，下方为所选任务详情。
            MainArea(sidebar: sidebar ?? .overview, selectedTask: $selectedTask)
        }
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
