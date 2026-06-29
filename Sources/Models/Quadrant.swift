import SwiftUI

/// 艾森豪威尔矩阵的四个象限。不持久化 —— 由任务的 isUrgent / isImportant 推导。
enum Quadrant: Int, CaseIterable, Identifiable, Hashable {
    case urgentImportant   // Q1：紧急且重要 —— 立即做
    case important         // Q2：重要不紧急 —— 计划做
    case urgent            // Q3：紧急不重要 —— 委派 / 快速做
    case neither           // Q4：不紧急不重要 —— 删减

    var id: Int { rawValue }

    init(isUrgent: Bool, isImportant: Bool) {
        switch (isUrgent, isImportant) {
        case (true, true):   self = .urgentImportant
        case (false, true):  self = .important
        case (true, false):  self = .urgent
        case (false, false): self = .neither
        }
    }

    /// 属于该象限的任务应具备的标志。
    var flags: (isUrgent: Bool, isImportant: Bool) {
        switch self {
        case .urgentImportant: return (true, true)
        case .important:       return (false, true)
        case .urgent:          return (true, false)
        case .neither:         return (false, false)
        }
    }

    var title: String {
        switch self {
        case .urgentImportant: return "紧急且重要"
        case .important:       return "重要不紧急"
        case .urgent:          return "紧急不重要"
        case .neither:         return "不紧急不重要"
        }
    }

    var actionHint: String {
        switch self {
        case .urgentImportant: return "立即做"
        case .important:       return "计划做"
        case .urgent:          return "委派 / 快速做"
        case .neither:         return "考虑删减"
        }
    }

    var symbol: String {
        switch self {
        case .urgentImportant: return "exclamationmark.2"
        case .important:       return "calendar"
        case .urgent:          return "bolt.fill"
        case .neither:         return "tray"
        }
    }

    var color: Color {
        switch self {
        case .urgentImportant: return .red
        case .important:       return .blue
        case .urgent:          return .orange
        case .neither:         return .secondary
        }
    }
}
