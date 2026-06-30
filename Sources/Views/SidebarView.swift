import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: SidebarItem?
    let weekStart: Date
    @AppStorage("showCompleted") private var showCompleted = false
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    private var tasks: [TaskItem] { allTasks.inWeek(weekStart) }

    var body: some View {
        List(selection: $selection) {
            Label(L("sidebar.overview"), systemImage: "square.grid.2x2")
                .tag(SidebarItem.overview)

            Section(L("sidebar.section.quadrants")) {
                ForEach(Quadrant.allCases) { q in
                    Label(q.title, systemImage: q.symbol)
                        .foregroundStyle(q.color)
                        .badge(tasks.count(in: .quadrant(q), showCompleted: showCompleted))
                        .tag(SidebarItem.scope(.quadrant(q)))
                        .dropDestination(for: TaskTransfer.self) { items, _ in
                            for item in items {
                                TaskMutations.move(uuid: item.taskUUID, to: q, in: context)
                            }
                            return !items.isEmpty
                        }
                }
            }

            Section(L("sidebar.section.lists")) {
                scopeRow(.all)
                scopeRow(.scheduled)
                scopeRow(.completed)
            }

            if !tags.isEmpty {
                Section(L("sidebar.section.tags")) {
                    ForEach(tags) { tag in
                        Label(tag.name, systemImage: "tag.fill")
                            .foregroundStyle(tag.color)
                            .badge(tasks.count(in: .tag(tag.name), showCompleted: showCompleted))
                            .tag(SidebarItem.scope(.tag(tag.name)))
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    @ViewBuilder
    private func scopeRow(_ scope: TaskScope) -> some View {
        Label(scope.title, systemImage: scope.symbol)
            .badge(tasks.count(in: scope, showCompleted: showCompleted))
            .tag(SidebarItem.scope(scope))
    }
}

#Preview {
    @Previewable @State var sel: SidebarItem? = .overview
    return NavigationStack { SidebarView(selection: $sel, weekStart: Week.currentStart) }
        .modelContainer(previewContainer)
}
