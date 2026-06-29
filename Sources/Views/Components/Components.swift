import SwiftUI

/// 高亮的工单号 badge；若有链接则可点击打开。
struct IssueKeyBadge: View {
    let key: String
    var url: URL? = nil

    private var label: some View {
        Text(key)
            .font(.caption2.weight(.semibold))
            .monospaced()
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
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tag.color.opacity(0.18), in: Capsule())
            .foregroundStyle(tag.color)
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

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { date != nil },
            set: { date = $0 ? (date ?? .now.addingTimeInterval(3600)) : nil }
        ))
        if date != nil {
            DatePicker(
                title,
                selection: Binding(get: { date ?? .now }, set: { date = $0 }),
                displayedComponents: components
            )
            .labelsHidden()
        }
    }
}
