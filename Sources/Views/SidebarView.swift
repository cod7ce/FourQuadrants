import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: SidebarItem?
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var allTasks: [TaskItem]
    @State private var showNewTag = false
    @State private var newTagName = ""
    #if os(iOS)
    var onSettings: () -> Void = {}
    #endif

    /// 该标签下的顶层任务数（含已完成，跨所有周）。
    private func taskCount(_ tag: Tag) -> Int {
        allTasks.filter {
            $0.parent == nil && $0.tagList.contains { $0.name == tag.name }
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 Logo（四色小田字，呼应四象限）
            HStack(spacing: 10) {
                AppLogoMark().frame(width: 26, height: 26)
                Text(L("app.title")).appFont(.title3, weight: .bold)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // 自绘紧凑侧栏（不用 .sidebar 列表，行高完全可控）
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    navRow(.overview, L("sidebar.overview"), .overview)
                    navRow(.thisWeek, L("sidebar.thisWeek"), .thisWeek)
                    navRow(.calendar, L("sidebar.calendar"), .calendar)

                    Text(L("sidebar.tags"))
                        .appFont(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 2)

                    ForEach(tags) { tag in tagRow(tag) }

                    Button { beginNewTag() } label: {
                        Label(L("editor.tag.new"), systemImage: "plus")
                            .appFont(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).frame(height: Self.rowHeight)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8).padding(.top, 4)
            }
            .frame(maxHeight: .infinity)
            .alert(L("editor.tag.new"), isPresented: $showNewTag) {
                TextField(L("editor.tag.new"), text: $newTagName)
                Button(L("action.add")) { addTag() }
                Button(L("action.cancel"), role: .cancel) { }
            }

            // Divider().padding(.horizontal, 12)

            // 底部：保存状态 + 设置
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(L("sidebar.savedLocal")).foregroundStyle(.secondary)
                }
                .appFont(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)

                settingsButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    /// 侧栏行的固定高度（自绘，完全可控）。
    private static let rowHeight: CGFloat = 30

    private func navRow(_ item: SidebarItem, _ title: String, _ icon: AppIcon) -> some View {
        rowButton(item) {
            HStack(spacing: 9) {
                AppIconView(icon: icon, size: 17)
                Text(title).appFont(.callout)
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        rowButton(.tag(tag.name)) {
            HStack(spacing: 10) {
                Circle().fill(tag.color).frame(width: 10, height: 10)
                Text(tag.name).appFont(.callout)
                Spacer(minLength: 6)
                Text("\(taskCount(tag))")
                    .appFont(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func rowButton(_ item: SidebarItem, @ViewBuilder _ label: () -> some View) -> some View {
        let selected = selection == item
        Button { selection = item } label: {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: Self.rowHeight)
                .background(selected ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(selected ? Color.accentColor : Color.appLabel)
        }
        .buttonStyle(.plain)
    }

    private func beginNewTag() {
        newTagName = ""
        showNewTag = true
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let hex = TagPalette.hexes[tags.count % TagPalette.hexes.count]
        context.insert(Tag(name: name, colorHex: hex))
        try? context.save()
    }

    private var settingsLabel: some View {
        HStack(spacing: 8) {
            AppIconView(icon: .settings, size: 16)
            Text(L("settings.title")).appFont(.callout)
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        #if os(macOS)
        SettingsLink {
            settingsLabel
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8).padding(.vertical, 4)
        #else
        Button { onSettings() } label: {
            settingsLabel
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8).padding(.vertical, 4)
        #endif
    }
}

/// 四色「田」字 Logo。
private struct AppLogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let g: CGFloat = 2
            let s = (geo.size.width - g) / 2
            VStack(spacing: g) {
                HStack(spacing: g) { cell(.red, s); cell(.blue, s) }
                HStack(spacing: g) { cell(.orange, s); cell(Color.secondary, s) }
            }
        }
    }
    private func cell(_ color: Color, _ s: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.9)).frame(width: s, height: s)
    }
}
