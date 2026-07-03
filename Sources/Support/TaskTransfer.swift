import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// 拖拽任务行时携带的轻量载荷（用稳定的 taskUUID）。
/// 用内置的 public.json 作为传输类型，避免自定义 UTType 需要在 Info.plist 登记。
struct TaskTransfer: Codable, Transferable {
    let taskUUID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
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

    /// 安排任务到指定「周 + 象限」（用于从待安排 Inbox 拖入某周视图）。
    @MainActor
    static func schedule(uuid: String, to quadrant: Quadrant, week: Date, in context: ModelContext) {
        guard let task = task(uuid: uuid, in: context) else { return }
        task.move(to: quadrant)
        task.weekStart = Week.start(of: week)
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }

    /// 把 `draggedUUID` 拖到 `target` 之前，并对该同级组重排 sortOrder。
    /// `ordered` 是目标所在同级组当前的显示顺序。跨象限拖入会一并归入目标象限。
    @MainActor
    static func reorder(draggedUUID: String, before target: TaskItem,
                        ordered: [TaskItem], in context: ModelContext) {
        guard draggedUUID != target.taskUUID,
              let dragged = task(uuid: draggedUUID, in: context) else { return }
        // 让被拖任务归入目标所在的组（子任务→同一父；顶层→目标象限）
        if let parent = target.parent {
            guard dragged.parent != nil else { return }   // 顶层任务不通过此路径变成子任务
            dragged.parent = parent
            dragged.weekStart = parent.weekStart
        } else {
            guard dragged.parent == nil else { return }   // 子任务不通过此路径变成顶层
            dragged.move(to: target.quadrant)
            dragged.weekStart = target.weekStart          // 跨周拖入时一并归到目标周
        }
        var arr = ordered.filter { $0.taskUUID != draggedUUID }
        guard let idx = arr.firstIndex(where: { $0.taskUUID == target.taskUUID }) else { return }
        arr.insert(dragged, at: idx)
        for (i, t) in arr.enumerated() { t.sortOrder = Double(i) }
        try? context.save()
    }
}
