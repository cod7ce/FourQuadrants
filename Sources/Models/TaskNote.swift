import Foundation
import SwiftData

/// 任务的一条「进度点评」。一个任务可有多条，列表里只显示最近一条。
///
/// CloudKit 约束：属性带默认值；关系可选且带 inverse；无唯一约束。
@Model
final class TaskNote {
    var text: String = ""
    var createdAt: Date = Date.now
    var task: TaskItem?

    init(text: String = "", createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}
