import SwiftUI
import SwiftData

/// 新建任务表单，支持「智能粘贴解析」：把整段工单文本拆成 工单号 / 标题 / 链接。
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let defaultQuadrant: Quadrant

    @State private var raw = ""
    @State private var parsed = ParsedTaskInput(issueKey: nil, title: "", links: [])
    @State private var quadrant: Quadrant

    init(defaultQuadrant: Quadrant) {
        self.defaultQuadrant = defaultQuadrant
        _quadrant = State(initialValue: defaultQuadrant)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("输入（可直接粘贴工单文本）") {
                    TextEditor(text: $raw)
                        .frame(minHeight: 90)
                        .autocorrectionDisabled()
                }

                if !parsed.isEmpty {
                    Section("解析预览") {
                        if let key = parsed.issueKey {
                            LabeledContent("工单号") { IssueKeyBadge(key: key) }
                        }
                        if !parsed.title.isEmpty {
                            LabeledContent("标题", value: parsed.title)
                        }
                        ForEach(parsed.links, id: \.self) { LinkRow(urlString: $0) }
                    }
                }

                Section("象限") {
                    Picker("象限", selection: $quadrant) {
                        ForEach(Quadrant.allCases) { q in
                            Text(q.title).tag(q)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                }
            }
            .formStyle(.grouped)
            .navigationTitle("新建任务")
            .onChange(of: raw) { _, value in
                parsed = TaskInputParser.parse(value)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: add)
                        .disabled(parsed.title.isEmpty && parsed.issueKey == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func add() {
        let flags = quadrant.flags
        let title = parsed.title.isEmpty ? (parsed.issueKey ?? "新任务") : parsed.title
        let task = TaskItem(title: title,
                            isUrgent: flags.isUrgent,
                            isImportant: flags.isImportant,
                            links: parsed.links,
                            issueKey: parsed.issueKey)
        context.insert(task)
        try? context.save()
        dismiss()
    }
}

#Preview {
    QuickAddView(defaultQuadrant: .urgentImportant)
        .modelContainer(previewContainer)
}
