import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// 拖拽任务行时携带的轻量载荷（用稳定的 taskUUID）。
struct TaskTransfer: Codable, Transferable {
    let taskUUID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .fourQuadrantsTask)
    }
}

extension UTType {
    static let fourQuadrantsTask = UTType(exportedAs: "com.cod7ce.FourQuadrants.task")
}

/// 在拖拽放下时按 uuid 解析任务并更新象限/排序的辅助。
enum TaskMutations {
    static func task(uuid: String, in context: ModelContext) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.taskUUID == uuid })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    static func move(uuid: String, to quadrant: Quadrant, in context: ModelContext) {
        guard let task = task(uuid: uuid, in: context) else { return }
        guard task.quadrant != quadrant else { return }
        task.move(to: quadrant)
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }
}
