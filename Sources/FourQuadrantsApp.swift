import SwiftUI
import SwiftData
#if os(macOS)
import RichTextKit
#endif

@main
struct FourQuadrantsApp: App {
    let container: ModelContainer
    @AppStorage(FontScale.key) private var fontIndex = FontScale.defaultIndex
    @AppStorage("showNotes") private var showNotes = false

    init() {
        container = Self.makeContainer()
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        #if os(macOS)
        .commands {
            SidebarCommands()
            RichTextCommand.FormatMenu()   // 备忘编辑器的 ⌘B/⌘I/⌘U 等格式菜单与快捷键
            CommandGroup(after: .sidebar) {
                Button(L("sidebar.overview")) { navigate(.overview) }
                    .keyboardShortcut("1", modifiers: .command)
                Button(L("sidebar.thisWeek")) { navigate(.thisWeek) }
                    .keyboardShortcut("2", modifiers: .command)
                Button(L("sidebar.calendar")) { navigate(.calendar) }
                    .keyboardShortcut("3", modifiers: .command)
                Divider()
                Button(L("menu.toggleNotes")) { showNotes.toggle() }
                    .keyboardShortcut("/", modifiers: .command)
                Divider()
                Button(L("menu.fontIncrease")) { fontIndex = FontScale.clamp(fontIndex + 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button(L("menu.fontDecrease")) { fontIndex = FontScale.clamp(fontIndex - 1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button(L("menu.fontReset")) { fontIndex = FontScale.defaultIndex }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
            }
        }
        #endif

        #if os(macOS)
        // 「设置…」菜单项（自带 ⌘,）
        Settings {
            SettingsView()
                .environment(\.locale, .app)
        }
        .modelContainer(container)   // 设置窗口也需要容器（标签管理用到 @Query/保存）
        #endif
    }

    #if os(macOS)
    /// 菜单快捷键切换主视图。
    private func navigate(_ item: SidebarItem) {
        NotificationCenter.default.post(name: .navigateSidebar, object: item)
    }
    #endif

    /// 优先创建 CloudKit 同步存储；若不可用（无 iCloud 账号 / 缺少权限 / 本地开发），
    /// 回退到本地存储，保证 app 始终可运行。
    static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, Tag.self, WeekNote.self, TaskNote.self])
        let cloudConfig = ModelConfiguration("FourQuadrants",
                                             schema: schema,
                                             cloudKitDatabase: .automatic)
        let container: ModelContainer
        if let c = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            container = c
        } else {
            let localConfig = ModelConfiguration("FourQuadrants-Local",
                                                 schema: schema,
                                                 cloudKitDatabase: .none)
            guard let c = try? ModelContainer(for: schema, configurations: [localConfig]) else {
                fatalError("无法创建 ModelContainer")
            }
            container = c
        }
        // 关闭自动保存：所有改动显式 save()，详情页编辑可用 rollback() 取消。
        container.mainContext.autosaveEnabled = false
        return container
    }
}
