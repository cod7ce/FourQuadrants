import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var name: String = ""
    var colorHex: String = "#1E88E5"
    var tasks: [TaskItem]? = []

    init(name: String = "", colorHex: String = "#1E88E5") {
        self.name = name
        self.colorHex = colorHex
    }
}

extension Tag {
    var color: Color { Color(hex: colorHex) ?? .blue }
}
