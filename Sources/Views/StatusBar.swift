import SwiftUI
import SwiftData

/// 终端主题底部状态栏：◆ 视图 · 版本 · pending/done … 收集箱 · 周 · 已保存。
struct StatusBar: View {
    @Environment(\.theme) private var theme
    let sidebar: SidebarItem
    let weekStart: Date
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]

    private var weekTop: [TaskItem] { allTasks.inWeek(weekStart).topLevel }
    private var done: Int { weekTop.filter(\.isCompleted).count }
    private var pending: Int { weekTop.count - done }
    private var inbox: Int { allTasks.filter { $0.parent == nil && !$0.isCompleted && $0.dueDate == nil }.count }
    private var weekNum: Int { Week.calendar.component(.weekOfYear, from: weekStart) }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    private var viewName: String {
        switch sidebar {
        case .overview:   return L("overview.title")
        case .thisWeek:   return L("sidebar.thisWeek")
        case .calendar:   return L("sidebar.calendar")
        case .tag(let n): return "#\(n)"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            seg("◆ \(viewName)", theme.accent, bold: true)
            sep(); seg("\(L("app.title")) v\(version)")
            sep(); seg("\(pending) pending · \(done) done")
            Spacer(minLength: 12)
            seg("\(L("inbox.title")):\(inbox)")
            sep(); seg("W\(weekNum)")
            sep(); seg("√ \(L("sidebar.savedLocal"))", theme.accent)
        }
        .appFont(.caption2, monospaced: true)
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.label.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func seg(_ text: String, _ color: Color = .secondary, bold: Bool = false) -> some View {
        Text(text).foregroundStyle(color).fontWeight(bold ? .semibold : .regular)
    }
    private func sep() -> some View {
        Text("∣").foregroundStyle(.tertiary).padding(.horizontal, 8)
    }
}

/// 终端主题顶部面包屑：~ / 应用名 / 当前视图。
struct BreadcrumbBar: View {
    @Environment(\.theme) private var theme
    let sidebar: SidebarItem

    private var leaf: String {
        switch sidebar {
        case .overview:   return "overview"
        case .thisWeek:   return "this-week"
        case .calendar:   return "calendar"
        case .tag(let n): return "tags/#\(n)"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            seg("~", .secondary)
            sep(); seg(L("app.title"), .secondary)
            sep(); seg(leaf, theme.accent)
            Spacer(minLength: 0)
        }
        .appFont(.caption2, monospaced: true)
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.label.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func seg(_ t: String, _ c: Color) -> some View { Text(t).foregroundStyle(c) }
    private func sep() -> some View {
        Text("/").foregroundStyle(.tertiary).padding(.horizontal, 6)
    }
}
