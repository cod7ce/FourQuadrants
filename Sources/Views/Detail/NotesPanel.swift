import SwiftUI

/// 笔记：独立窗口内容。所选周通过 AppStorage 共享，跟随主窗口切换。
struct NotesWindow: View {
    @AppStorage("notesWeekStamp") private var stamp: Double = 0

    private var weekStart: Date {
        stamp == 0 ? Week.currentStart
                   : Week.start(of: Date(timeIntervalSinceReferenceDate: stamp))
    }

    var body: some View {
        MemoEditor(weekStart: weekStart)
            .id(weekStart)                       // 切周时重建，加载该周内容
            .frame(minWidth: 360, minHeight: 320)
            .navigationTitle("\(L("notes.title")) · \(Week.yearWeekLabel(weekStart))")
    }
}
