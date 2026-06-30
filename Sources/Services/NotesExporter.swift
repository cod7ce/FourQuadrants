#if os(macOS)
import Foundation
import SwiftData
import AppKit

/// 把某一周的任务导出到「备忘录」指定文件夹。
/// 笔记标题为周号；同名笔记先删除再新建（覆盖）。
/// nativeChecklist=true 时用 GUI 自动化生成「原生可勾选清单」（实验性，需辅助功能授权）；
/// 否则用稳健的 HTML（☐/☑ + 删除线）。
enum NotesExporter {

    @MainActor
    @discardableResult
    static func export(weekStart: Date, folder: String,
                       nativeChecklist: Bool, context: ModelContext) -> Bool {
        let title = Week.yearWeekLabel(weekStart)
        let source = nativeChecklist
            ? nativeScript(folder: folder, title: title, weekStart: weekStart, context: context)
            : htmlScript(folder: folder, title: title,
                         html: buildHTML(weekStart: weekStart, title: title, context: context))

        guard let script = NSAppleScript(source: source) else {
            alert(title: L("export.failed"), message: "无法创建 AppleScript")
            return false
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let msg = (error["NSAppleScriptErrorMessage"] as? String) ?? "\(error)"
            let num = (error["NSAppleScriptErrorNumber"] as? Int).map { " (\($0))" } ?? ""
            alert(title: L("export.failed"), message: msg + num)
            return false
        }
        return true
    }

    private static func alert(title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }

    private static func tasks(weekStart: Date, context: ModelContext) -> [TaskItem] {
        let all = (try? context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        return all.inWeek(weekStart).topLevel
    }

    private static func line(for t: TaskItem) -> String {
        var s = ""
        if let key = t.issueKey { s += "[\(key)] " }
        s += t.title.isEmpty ? L("detail.title.untitled") : t.title
        if let due = t.dueDate { s += " · " + due.formatted(.dateTime.month().day().locale(.app)) }
        let tags = t.tagList.map { "#\($0.name)" }.joined(separator: " ")
        if !tags.isEmpty { s += " · " + tags }
        let subs = t.sortedSubtasks
        if !subs.isEmpty { s += " · \(subs.filter(\.isCompleted).count)/\(subs.count)" }
        return s
    }

    // MARK: 原生清单（GUI 自动化）

    private static func nativeScript(folder: String, title: String,
                                     weekStart: Date, context: ModelContext) -> String {
        let f = asEscape(folder)
        let t = asEscape(title)
        let weekTasks = tasks(weekStart: weekStart, context: context)

        var se: [String] = []
        // 第一行作为标题
        se.append("keystroke \"\(t)\"")
        se.append("keystroke return")
        let sub = Week.label(weekStart) + " · "
            + Date().formatted(.dateTime.year().month().day().hour().minute().locale(.app))
        se.append("keystroke \"\(asEscape(sub))\"")
        se.append("keystroke return")

        for quadrant in Quadrant.allCases {
            let items = weekTasks.filter { $0.quadrant == quadrant }
            let done = items.filter(\.isCompleted).count
            se.append("keystroke return")
            se.append("keystroke \"\(asEscape("\(quadrant.title) · \(done)/\(items.count)"))\"")
            se.append("keystroke return")

            if items.isEmpty {
                se.append("keystroke \"\(asEscape(L("grid.empty")))\"")
                continue
            }
            // 开启清单格式
            se.append("keystroke \"l\" using {command down, shift down}")
            for (idx, task) in items.enumerated() {
                se.append("keystroke \"\(asEscape(line(for: task)))\"")
                if task.isCompleted {
                    // 切换勾选（不同版本可能不同，必要时调整）
                    se.append("keystroke \"u\" using {command down, shift down}")
                }
                if idx < items.count - 1 {
                    se.append("keystroke return")
                }
            }
            // 结束清单：换行后再次按 ⌘⇧L 取消清单格式
            se.append("keystroke return")
            se.append("keystroke \"l\" using {command down, shift down}")
        }

        let body = se.joined(separator: "\n            ")
        // 安全做法：只按标题精准删除同名笔记，绝不用 ⌘A 全选删除（会误删整文件夹）。
        return """
        tell application id "com.apple.Notes"
            activate
            if not (exists folder "\(f)") then make new folder with properties {name:"\(f)"}
            set theFolder to folder "\(f)"
            repeat with n in (notes of theFolder whose name is "\(t)")
                delete n
            end repeat
            set theNote to make new note at theFolder with properties {body:""}
            show theNote
        end tell
        delay 0.7
        tell application "System Events"
            tell process "Notes"
                set frontmost to true
                \(body)
            end tell
        end tell
        """
    }

    // MARK: HTML 兜底（☐/☑）

    private static func buildHTML(weekStart: Date, title: String, context: ModelContext) -> String {
        let weekTasks = tasks(weekStart: weekStart, context: context)
        var html = "<h1>\(htmlEscape(title))</h1>"
        let now = Date().formatted(.dateTime.year().month().day().hour().minute().locale(.app))
        html += "<div>\(htmlEscape(Week.label(weekStart))) · \(htmlEscape(now))</div>"

        for quadrant in Quadrant.allCases {
            let items = weekTasks.filter { $0.quadrant == quadrant }
            let done = items.filter(\.isCompleted).count
            html += "<h2>\(htmlEscape(quadrant.title)) · \(done)/\(items.count)</h2>"
            guard !items.isEmpty else {
                html += "<div>\(htmlEscape(L("grid.empty")))</div>"
                continue
            }
            for t in items {
                let box = t.isCompleted ? "☑ " : "☐ "
                var inner = htmlEscape(line(for: t))
                if let url = t.urls.first {
                    inner = "<a href=\"\(htmlEscape(url.absoluteString))\">\(inner)</a>"
                }
                if t.isCompleted { inner = "<s>\(inner)</s>" }
                html += "<div>\(box)\(inner)</div>"
            }
        }
        return html
    }

    private static func htmlScript(folder: String, title: String, html: String) -> String {
        let f = asEscape(folder)
        let t = asEscape(title)
        let body = asEscape(html)
        return """
        tell application id "com.apple.Notes"
            activate
            if not (exists folder "\(f)") then make new folder with properties {name:"\(f)"}
            set theFolder to folder "\(f)"
            set matchingNotes to (notes of theFolder whose name is "\(t)")
            if (count of matchingNotes) > 0 then
                set theNote to item 1 of matchingNotes
                set body of theNote to "\(body)"
                repeat with i from (count of matchingNotes) to 2 by -1
                    delete (item i of matchingNotes)
                end repeat
            else
                set theNote to make new note at theFolder with properties {body:"\(body)"}
            end if
            show theNote
        end tell
        """
    }

    // MARK: 转义

    private static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func asEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
#endif
