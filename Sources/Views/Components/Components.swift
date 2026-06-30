import SwiftUI

/// 高亮的工单号 badge；若有链接则可点击打开。
struct IssueKeyBadge: View {
    let key: String
    var url: URL? = nil

    private var label: some View {
        Text(key)
            .appFont(.caption2, weight: .semibold, monospaced: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    var body: some View {
        if let url {
            Link(destination: url) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }
}

struct TagChip: View {
    let tag: Tag
    var body: some View {
        Text(tag.name)
            .appFont(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tag.color.opacity(0.18), in: Capsule())
            .foregroundStyle(tag.color)
    }
}

/// 右侧的截止日期（仅日期）；过期显示红色。
struct DueDateLabel: View {
    let task: TaskItem
    var body: some View {
        if let due = task.dueDate {
            Text(due.formatted(.dateTime.month().day().locale(.app)))
                .appFont(.caption, monospacedDigit: true)
                .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
        }
    }
}

struct CompletionToggle: View {
    let isCompleted: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

/// 列表行内可点击的链接：单个直接打开，多个弹出菜单选择。
struct TaskLinksButton: View {
    let urls: [URL]

    var body: some View {
        if urls.count == 1, let url = urls.first {
            Link(destination: url) {
                Label(L("component.link"), systemImage: "link")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        } else if urls.count > 1 {
            Menu {
                ForEach(urls, id: \.self) { url in
                    Link(url.host() ?? url.absoluteString, destination: url)
                }
            } label: {
                Label("\(urls.count)", systemImage: "link")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.tint)
        }
    }
}

struct LinkRow: View {
    let urlString: String
    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Label(url.host() ?? urlString, systemImage: "link")
                    .lineLimit(1)
            }
        } else {
            Label(urlString, systemImage: "link").lineLimit(1)
        }
    }
}

/// 可选日期行：开关 + 出现时显示 DatePicker。
struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?
    var components: DatePickerComponents = [.date, .hourAndMinute]
    /// 若设置，时间会吸附到该分钟间隔（如 30）。
    var snapMinutes: Int? = nil

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { date != nil },
            set: { date = $0 ? (date ?? snap(.now.addingTimeInterval(3600))) : nil }
        ))
        if date != nil {
            DatePicker(
                title,
                selection: Binding(get: { date ?? .now }, set: { date = snap($0) }),
                displayedComponents: components
            )
            .labelsHidden()
        }
    }

    private func snap(_ d: Date) -> Date {
        guard let interval = snapMinutes, interval > 0 else { return d }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        let minute = comps.minute ?? 0
        let rounded = Int((Double(minute) / Double(interval)).rounded()) * interval
        comps.minute = 0
        comps.second = 0
        let base = cal.date(from: comps) ?? d
        return cal.date(byAdding: .minute, value: rounded, to: base) ?? d
    }
}
