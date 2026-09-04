import Foundation
import SwiftData

/// 一条任务。命名为 TaskItem 以避免与 Swift 并发的 `Task` 冲突。
///
/// CloudKit 约束：所有属性可选或带默认值；关系可选且带 inverse；无唯一约束。
@Model
final class TaskItem {
    var title: String = ""
    var notes: String = ""

    var isUrgent: Bool = false
    var isImportant: Bool = false

    var isCompleted: Bool = false
    var completedAt: Date?

    var dueDate: Date?
    var remindAt: Date?

    var createdAt: Date = Date.now
    var sortOrder: Double = 0

    /// 所属周的起始（周一 00:00）。每周内容相互独立。
    var weekStart: Date = Date.now

    /// 外部链接（URL 字符串）。
    var links: [String] = []
    /// 工单号，如 ONES2-2296709。
    var issueKey: String?

    /// 稳定标识，用于本地通知的调度/取消（不要用 hashValue —— 跨启动不稳定）。
    var taskUUID: String = UUID().uuidString

    // 自引用子任务
    var parent: TaskItem?
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem]? = []

    @Relationship(inverse: \Tag.tasks)
    var tags: [Tag]? = []

    /// 进度点评（多条，按时间倒序看最近一条）。
    @Relationship(deleteRule: .cascade, inverse: \TaskNote.task)
    var progressNotes: [TaskNote]? = []

    /// 详细内容：富文本（RTFD，内嵌粘贴的图片），可直接编辑、图文混排。
    @Attribute(.externalStorage) var richContent: Data?

    init(title: String = "",
         notes: String = "",
         isUrgent: Bool = false,
         isImportant: Bool = false,
         dueDate: Date? = nil,
         remindAt: Date? = nil,
         links: [String] = [],
         issueKey: String? = nil,
         sortOrder: Double = 0,
         weekStart: Date = Week.currentStart) {
        self.title = title
        self.notes = notes
        self.isUrgent = isUrgent
        self.isImportant = isImportant
        self.dueDate = dueDate
        self.remindAt = remindAt
        self.links = links
        self.issueKey = issueKey
        self.sortOrder = sortOrder
        self.weekStart = weekStart
        self.createdAt = .now
        self.taskUUID = UUID().uuidString
    }
}

extension TaskItem {
    /// 由两个标志推导的象限。
    var quadrant: Quadrant {
        Quadrant(isUrgent: isUrgent, isImportant: isImportant)
    }

    /// 移动到目标象限 —— 翻转两个标志。
    func move(to quadrant: Quadrant) {
        let flags = quadrant.flags
        isUrgent = flags.isUrgent
        isImportant = flags.isImportant
    }

    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? .now : nil
    }

    var sortedSubtasks: [TaskItem] {
        (subtasks ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - 层级（多级子任务，最深 3 层）

    /// 子任务最大深度：顶层=1，其子=2，孙=3；第 3 层不能再加子。
    static let maxDepth = 3

    /// 层级：顶层=1，其子=2，孙=3。带环防御。
    var depth: Int {
        var d = 1, p = parent, hops = 0
        while let cur = p, hops < 64 { d += 1; p = cur.parent; hops += 1 }
        return d
    }

    /// 还能不能再加子任务（未到最大深度）。
    var canHaveChildren: Bool { depth < Self.maxDepth }

    /// 以自己为根的子树高度：叶=1。用于拖拽时判断放进去会不会超深。
    var subtreeHeight: Int {
        let kids = subtasks ?? []
        if kids.isEmpty { return 1 }
        return 1 + (kids.map(\.subtreeHeight).max() ?? 0)
    }

    /// self 是否是 node 的后代（沿 parent 向上能找到 node）。用于防止把节点拖进自己的子树成环。
    func isDescendant(of node: TaskItem) -> Bool {
        var p = parent, hops = 0
        while let cur = p, hops < 64 {
            if cur.taskUUID == node.taskUUID { return true }
            p = cur.parent; hops += 1
        }
        return false
    }

    /// 递归设置整棵子树的所属周（跨周结转时保持一致）。
    func setWeekStartDeep(_ week: Date) {
        weekStart = week
        for sub in subtasks ?? [] { sub.setWeekStartDeep(week) }
    }

    var tagList: [Tag] {
        (tags ?? []).sorted { $0.name < $1.name }
    }

    /// 进度点评，按时间倒序（最近的在前）。
    var sortedNotes: [TaskNote] {
        (progressNotes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// 最近一条点评（列表里显示这条）。
    var latestNote: TaskNote? { sortedNotes.first }

    /// 议程 / 日历里归属的日期：已完成用「完成日」，未完成用「截止日」。
    var agendaDate: Date? { isCompleted ? (completedAt ?? dueDate) : dueDate }

    var urls: [URL] {
        links.compactMap { URL(string: $0) }
    }

    var notificationID: String { "task-\(taskUUID)" }

    /// 是否过期：截止日期按当天 23:59:59 计算。
    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: due) ?? due
        return endOfDay < .now
    }
}
