import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#1E88E5"
    var sortOrder: Double = 0
    var tasks: [TaskItem]? = []

    init(name: String = "", colorHex: String = "#1E88E5", sortOrder: Double = 0) {
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}

extension Tag {
    var color: Color { Color(hex: colorHex) ?? .blue }
}
