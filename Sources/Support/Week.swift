import Foundation

/// 「周」相关的计算。以周一为一周起始。
enum Week {
    static var calendar: Calendar {
        var c = Calendar.current
        c.locale = .app
        c.firstWeekday = 2          // 周一
        c.minimumDaysInFirstWeek = 4 // ISO 周编号
        return c
    }

    /// 某日期所在周的起始（归一化到周一 00:00）。
    static func start(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    static var currentStart: Date { start(of: .now) }

    static func isCurrent(_ weekStart: Date) -> Bool {
        calendar.isDate(weekStart, equalTo: .now, toGranularity: .weekOfYear)
    }

    static func shift(_ weekStart: Date, by weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) ?? weekStart
    }

    /// 两个日期是否属于同一周。
    static func same(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, equalTo: b, toGranularity: .weekOfYear)
    }

    /// 形如 “6月23日 – 6月29日”。
    static func label(_ weekStart: Date) -> String {
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let s = weekStart.formatted(.dateTime.month().day().locale(.app))
        let e = end.formatted(.dateTime.month().day().locale(.app))
        return "\(s) – \(e)"
    }

    /// 形如 “2026 年第 27 周”。
    static func yearWeekLabel(_ weekStart: Date) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        let year = comps.yearForWeekOfYear ?? calendar.component(.year, from: weekStart)
        let week = comps.weekOfYear ?? 0
        return String(format: L("week.yearWeek"), year, week)
    }
}
