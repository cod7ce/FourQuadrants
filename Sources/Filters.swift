import Foundation

/// 任务列表的范围（侧栏选择）。
enum TaskScope: Hashable {
    case all
    case quadrant(Quadrant)
    case scheduled      // 有截止日期
    case completed
    case tag(String)    // 按标签名

    var title: String {
        switch self {
        case .all:            return L("scope.all")
        case .quadrant(let q): return q.title
        case .scheduled:      return L("scope.scheduled")
        case .completed:      return L("scope.completed")
        case .tag(let name):  return "#\(name)"
        }
    }

    var symbol: String {
        switch self {
        case .all:            return "tray.full"
        case .quadrant(let q): return q.symbol
        case .scheduled:      return "calendar"
        case .completed:      return "checkmark.circle"
        case .tag:            return "tag"
        }
    }
}

/// 基于内存数组的过滤辅助 —— 对个人规模的数据足够，且避免 SwiftData 关系谓词的边角问题。
extension Array where Element == TaskItem {
    /// 仅属于指定周的任务。
    func inWeek(_ weekStart: Date) -> [TaskItem] {
        filter { Week.same($0.weekStart, weekStart) }
    }

    /// 仅顶层任务（非子任务）。
    var topLevel: [TaskItem] { filter { $0.parent == nil } }
    var active: [TaskItem] { filter { !$0.isCompleted } }
    var completed: [TaskItem] { filter { $0.isCompleted } }

    func inScope(_ scope: TaskScope, showCompleted: Bool = false) -> [TaskItem] {
        let top = topLevel
        func visible(_ arr: [TaskItem]) -> [TaskItem] {
            showCompleted ? arr : arr.filter { !$0.isCompleted }
        }
        switch scope {
        case .all:
            return visible(top)
        case .quadrant(let q):
            return visible(top.filter { $0.quadrant == q })
        case .scheduled:
            return visible(top.filter { $0.dueDate != nil })
        case .completed:
            return top.completed
        case .tag(let name):
            return visible(top.filter { $0.tagList.contains { $0.name == name } })
        }
    }

    func count(in scope: TaskScope, showCompleted: Bool = false) -> Int {
        inScope(scope, showCompleted: showCompleted).count
    }
}
