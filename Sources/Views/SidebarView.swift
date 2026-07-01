import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    #if os(iOS)
    var onSettings: () -> Void = {}
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部 Logo（四色小田字，呼应四象限）
            HStack(spacing: 10) {
                AppLogoMark().frame(width: 26, height: 26)
                Text(L("app.title")).font(.title3.bold())
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            List(selection: $selection) {
                row(.overview, L("sidebar.overview"), "square.grid.2x2")
                row(.thisWeek, L("sidebar.thisWeek"), "calendar")
                row(.calendar, L("sidebar.calendar"), "clock")
                row(.tags, L("sidebar.tags"), "tag")
                row(.archive, L("sidebar.archive"), "archivebox")
            }
            #if os(macOS)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            #endif

            Divider().padding(.horizontal, 12)

            // 底部：保存状态 + 设置
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(L("sidebar.savedLocal")).foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)

                settingsButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private func row(_ item: SidebarItem, _ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).tag(item)
    }

    @ViewBuilder
    private var settingsButton: some View {
        #if os(macOS)
        SettingsLink {
            Label(L("settings.title"), systemImage: "gearshape")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8).padding(.vertical, 4)
        #else
        Button { onSettings() } label: {
            Label(L("settings.title"), systemImage: "gearshape")
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
