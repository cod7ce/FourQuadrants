import Foundation
import SwiftData

/// 预览与首次启动的示例数据。
enum SampleData {
    @MainActor
    static func populate(_ context: ModelContext) {
        let work = Tag(name: "工作", colorHex: "#1E88E5")
        let home = Tag(name: "生活", colorHex: "#43A047")
        context.insert(work)
        context.insert(home)

        let t1 = TaskItem(title: "准备季度评审材料",
                          isUrgent: true, isImportant: true,
                          dueDate: .now.addingTimeInterval(3600),
                          links: ["https://example.com/docs/quarterly-review"],
                          issueKey: "DEMO-1024",
                          sortOrder: 0)
        t1.tags = [work]
        let sub = TaskItem(title: "整理关键数据图表", isUrgent: true, isImportant: true, sortOrder: 0)
        sub.parent = t1
        t1.richContent = RichText.data(NSAttributedString(
            string: "汇总上季度的关键指标，做成一页概览。下一步：先把数据源对齐，再画图。"))
        context.insert(t1)
        context.insert(sub)

        let t2 = TaskItem(title: "规划下季度路线图", isImportant: true,
                          dueDate: .now.addingTimeInterval(86400 * 7), sortOrder: 1)
        t2.tags = [work]
        context.insert(t2)

        let t3 = TaskItem(title: "回复非紧要邮件", isUrgent: true, sortOrder: 2)
        context.insert(t3)

        let t4 = TaskItem(title: "整理收藏夹", sortOrder: 3)
        t4.tags = [home]
        context.insert(t4)

        try? context.save()
    }

    /// 供 TaskDetailView 预览使用的单条任务。
    @MainActor
    static var previewTask: TaskItem {
        let context = previewContainer.mainContext
        let descriptor = FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)])
        if let first = try? context.fetch(descriptor).first(where: { $0.parent == nil }) {
            return first
        }
        let t = TaskItem(title: "示例任务", isUrgent: true, isImportant: true,
                         issueKey: "DEMO-1024")
        context.insert(t)
        return t
    }
}
