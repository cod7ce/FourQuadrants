import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: SidebarItem?
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query(sort: \Tag.name) private var tags: [Tag]

    var body: some View {
        List(selection: $selection) {
            Label("总览", systemImage: "square.grid.2x2")
                .tag(SidebarItem.overview)

            Section("象限") {
                ForEach(Quadrant.allCases) { q in
                    Label(q.title, systemImage: q.symbol)
                        .foregroundStyle(q.color)
                        .badge(tasks.count(in: .quadrant(q)))
                        .tag(SidebarItem.scope(.quadrant(q)))
                        .dropDestination(for: TaskTransfer.self) { items, _ in
                            for item in items {
                                TaskMutations.move(uuid: item.taskUUID, to: q, in: context)
                            }
                            return !items.isEmpty
                        }
                }
            }

            Section("清单") {
                scopeRow(.all)
                scopeRow(.scheduled)
                scopeRow(.completed)
            }

            if !tags.isEmpty {
                Section("标签") {
                    ForEach(tags) { tag in
                        Label(tag.name, systemImage: "tag.fill")
                            .foregroundStyle(tag.color)
                            .badge(tasks.count(in: .tag(tag.name)))
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
            .badge(tasks.count(in: scope))
            .tag(SidebarItem.scope(scope))
    }
}

#Preview {
    @Previewable @State var sel: SidebarItem? = .overview
    return NavigationStack { SidebarView(selection: $sel) }
        .modelContainer(previewContainer)
}
