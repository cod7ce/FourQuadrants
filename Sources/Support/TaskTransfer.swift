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
            // 目标是子任务 → 被拖任务归到 target 的父下（同级插队）
            guard newParent.taskUUID != dragged.taskUUID,                       // 不能挂到自己名下
                  !newParent.isDescendant(of: dragged),                         // 防环：不能进自己的子树
                  newParent.depth + dragged.subtreeHeight <= TaskItem.maxDepth  // 放进去不超 3 层
            else { return }
            dragged.parent = newParent
            dragged.setWeekStartDeep(newParent.weekStart)
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

    /// 更早周里、未完成的顶层任务（用于「整理到本周」）。
    @MainActor
    static func carryForwardSources(into target: Date, in context: ModelContext) -> [TaskItem] {
        let week = Week.start(of: target)
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return all.filter {
            $0.parent == nil && !$0.isCompleted && Week.start(of: $0.weekStart) < week
        }
    }

    /// 整理时对单个任务采取的动作（也用于确认框逐行展示）。
    enum CarryAction { case move, copyParent, complete }

    /// 判定某个历史未完成任务会怎么处理：
    /// 无子任务 → 移动；有未完成子任务 → 复制父+移动子+原件完成；子任务全完成 → 标记完成。
    static func carryAction(for t: TaskItem) -> CarryAction {
        let subs = t.sortedSubtasks
        if subs.isEmpty { return .move }
        if subs.contains(where: { !$0.isCompleted }) { return .copyParent }
        return .complete
    }

    /// 把选中的历史未完成任务整理到目标周（规则见 `carryAction`）。返回处理数量。
    @MainActor
    @discardableResult
    static func carryForward(_ tasks: [TaskItem], into target: Date, in context: ModelContext) -> Int {
        let week = Week.start(of: target)
        for t in tasks {
            switch carryAction(for: t) {
            case .move:
                // 无子任务：整条移动到目标周，作为新一周的待办重新开始。
                t.weekStart = week
                t.dueDate = nil
                t.remindAt = nil
            case .copyParent:
                // 有未完成子任务：复制父任务到目标周，未完成子任务移动到副本下，原件标记完成。
                let copy = TaskItem(title: t.title,
                                    notes: t.notes,
                                    isUrgent: t.isUrgent,
                                    isImportant: t.isImportant,
                                    links: t.links,
                                    issueKey: t.issueKey,
                                    sortOrder: t.sortOrder,
                                    weekStart: week)
                copy.tags = t.tags
                copy.richContent = t.richContent
                context.insert(copy)
                for sub in t.sortedSubtasks where !sub.isCompleted {
                    sub.parent = copy
                    sub.setWeekStartDeep(week)   // 连带其自身子树一起搬到目标周
                    sub.dueDate = nil
                    sub.remindAt = nil
                }
                completeInPlace(t)
            case .complete:
                // 子任务全部完成：父任务标记完成。
                completeInPlace(t)
            }
        }
        try? context.save()
        return tasks.count
    }

    private static func completeInPlace(_ t: TaskItem) {
        guard !t.isCompleted else { return }
        t.isCompleted = true
        t.completedAt = .now
    }

    /// 把任务挂到 `newParent` 下成为其子任务（用于拖到父任务主体上，含没有子任务的父）。
    /// 支持多级（最深 3 层）：放进去后的总深度不能超过 `maxDepth`，且不能形成环。
    @MainActor
    static func makeChild(uuid: String, of newParent: TaskItem, in context: ModelContext) {
        guard let dragged = task(uuid: uuid, in: context),
              dragged.taskUUID != newParent.taskUUID,
              !newParent.isDescendant(of: dragged),                          // 防环：不能进自己的子树
              newParent.depth + dragged.subtreeHeight <= TaskItem.maxDepth   // 放进去不超 3 层
        else { return }
        guard dragged.parent?.taskUUID != newParent.taskUUID else { return }   // 已是它的子任务
        dragged.parent = newParent
        dragged.setWeekStartDeep(newParent.weekStart)
        dragged.sortOrder = (newParent.sortedSubtasks.map(\.sortOrder).max() ?? -1) + 1
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: dragged) }
    }

    /// 把任务作为顶层任务放入指定象限/周，插到 `before` 之前（`before` 为 nil = 末尾），并重排同级序号。
    /// 供总览自定义拖拽落位使用（跨象限移动 + 同象限重排统一走这里）。
    @MainActor
    static func place(uuid: String, into quadrant: Quadrant, before: TaskItem?,
                      week: Date, in context: ModelContext) {
        guard let dragged = task(uuid: uuid, in: context) else { return }
        let flags = quadrant.flags
        let weekStart = Week.start(of: week)
        dragged.parent = nil
        dragged.move(to: quadrant)
        dragged.weekStart = weekStart

        let all = (try? context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var ordered = all.filter {
            $0.parent == nil && $0.taskUUID != uuid && !$0.isCompleted &&
            $0.isUrgent == flags.isUrgent && $0.isImportant == flags.isImportant &&
            Week.start(of: $0.weekStart) == weekStart
        }
        let at = before.flatMap { b in ordered.firstIndex { $0.taskUUID == b.taskUUID } } ?? ordered.count
        ordered.insert(dragged, at: min(at, ordered.count))
        for (i, t) in ordered.enumerated() { t.sortOrder = Double(i) }
        try? context.save()
        Task { await NotificationManager.shared.reschedule(for: dragged) }
    }
}
