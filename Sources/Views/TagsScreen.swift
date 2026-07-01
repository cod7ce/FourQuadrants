import SwiftUI
import SwiftData

/// 侧栏「标签」：列出所有标签，点击进入该标签的任务列表。
struct TagsScreen: View {
    @Binding var selectedTask: TaskItem?
    let weekStart: Date
    @Query(sort: \Tag.name) private var tags: [Tag]

    var body: some View {
        List {
            if tags.isEmpty {
                Text(L("settings.tags.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    NavigationLink {
                        TaskListView(scope: .tag(tag.name),
                                     selectedTask: $selectedTask, weekStart: weekStart)
                    } label: {
                        Label(tag.name, systemImage: "tag.fill").foregroundStyle(tag.color)
                    }
                }
            }
        }
        .navigationTitle(L("sidebar.tags"))
    }
}
