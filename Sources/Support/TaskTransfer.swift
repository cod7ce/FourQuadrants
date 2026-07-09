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

    /// 安排任务到某一天（本周议程：从待安排拖到某天，或在天之间移动）。
    /// 设置截止日期为当天 00:00，并把所属周同步到该天所在周。
    @MainActor
    static func schedule(uuid: String, onDay day: Date, in context: ModelContext) {
        guard let task = task(uuid: uuid, in: context) else { return }
        task.dueDate = Week.calendar.startOfDay(for: day)
        task.weekStart = Week.start(of: day)
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: task) }
    }

    /// 把 `draggedUUID` 拖到 `target` 之前，并对该同级组重排 sortOrder。
    /// 会按目标行的层级自动改父级，支持跨层级拖拽：
    /// - 拖到某父任务下的子任务前 → 成为该父的子任务（顶层任务下沉、或换到别的父下）
    /// - 拖到某顶层任务前 → 成为顶层任务（子任务提升为独立任务，并归入目标象限/周）
    @MainActor
    static func reorder(draggedUUID: String, before target: TaskItem,
                        ordered: [TaskItem], in context: ModelContext) {
        guard draggedUUID != target.taskUUID,
              let dragged = task(uuid: draggedUUID, in: context) else { return }

        if let newParent = target.parent {
            // 目标是子任务 → 被拖任务归到 target 的父下
            guard newParent.taskUUID != dragged.taskUUID else { return }   // 不能挂到自己名下
            guard dragged.sortedSubtasks.isEmpty else { return }           // 保持单层：有子任务的不下沉
            dragged.parent = newParent
            dragged.weekStart = newParent.weekStart
        } else {
            // 目标是顶层任务 → 被拖任务成为/保持顶层，并归入目标象限与周
            dragged.parent = nil
            dragged.move(to: target.quadrant)
            dragged.weekStart = target.weekStart
        }

        var arr = ordered.filter { $0.taskUUID != draggedUUID }
        guard let idx = arr.firstIndex(where: { $0.taskUUID == target.taskUUID }) else { return }
        arr.insert(dragged, at: idx)
        for (i, t) in arr.enumerated() { t.sortOrder = Double(i) }
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: dragged) }
    }

    /// 把任务挂到 `newParent` 下成为其子任务（用于拖到父任务主体上，含没有子任务的父）。
    /// 保持单层：`newParent` 必须是顶层任务，且被拖任务自身不能带子任务。
    @MainActor
    static func makeChild(uuid: String, of newParent: TaskItem, in context: ModelContext) {
        guard let dragged = task(uuid: uuid, in: context),
              dragged.taskUUID != newParent.taskUUID,
              newParent.parent == nil,
              dragged.sortedSubtasks.isEmpty else { return }
        guard dragged.parent?.taskUUID != newParent.taskUUID else { return }   // 已是它的子任务
        dragged.parent = newParent
        dragged.weekStart = newParent.weekStart
        dragged.sortOrder = (newParent.sortedSubtasks.map(\.sortOrder).max() ?? -1) + 1
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: dragged) }
    }
}
