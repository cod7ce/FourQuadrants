import SwiftUI
import SwiftData

@main
struct FourQuadrantsApp: App {
    let container: ModelContainer

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
        }
        #endif
    }

    /// 优先创建 CloudKit 同步存储；若不可用（无 iCloud 账号 / 缺少权限 / 本地开发），
    /// 回退到本地存储，保证 app 始终可运行。
    static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, Tag.self])
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
