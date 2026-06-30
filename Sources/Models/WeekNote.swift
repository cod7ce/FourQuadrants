import Foundation
import SwiftData

/// 每周一份的备忘（原生富文本，编码后的 AttributedString）。
@Model
final class WeekNote {
    var weekStart: Date = Date.now
    @Attribute(.externalStorage) var content: Data?

    init(weekStart: Date) {
        self.weekStart = weekStart
    }
}
