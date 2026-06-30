import SwiftData

/// 内存中的预览容器，便于在不依赖 CloudKit 的情况下迭代 UI。
@MainActor
let previewContainer: ModelContainer = {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskItem.self, Tag.self, WeekNote.self, configurations: config)
    SampleData.populate(container.mainContext)
    return container
}()
