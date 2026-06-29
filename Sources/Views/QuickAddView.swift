import SwiftUI
import SwiftData

/// 新建任务表单，支持「智能粘贴解析」：把整段工单文本拆成 工单号 / 标题 / 链接。
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let defaultQuadrant: Quadrant
    let weekStart: Date

    @State private var raw = ""
    @State private var parsed = ParsedTaskInput(issueKey: nil, title: "", links: [])
    @State private var quadrant: Quadrant

    init(defaultQuadrant: Quadrant, weekStart: Date) {
        self.defaultQuadrant = defaultQuadrant
        self.weekStart = weekStart
        _quadrant = State(initialValue: defaultQuadrant)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("add.input.section")) {
                    TextEditor(text: $raw)
                        .frame(minHeight: 90)
                        .autocorrectionDisabled()
                }

                if !parsed.isEmpty {
                    Section(L("add.preview.section")) {
                        if let key = parsed.issueKey {
                            LabeledContent(L("add.preview.issueKey")) { IssueKeyBadge(key: key) }
                        }
                        if !parsed.title.isEmpty {
                            LabeledContent(L("add.preview.title"), value: parsed.title)
                        }
                        ForEach(parsed.links, id: \.self) { LinkRow(urlString: $0) }
                    }
                }

                Section(L("add.section.quadrant")) {
                    Picker(L("add.section.quadrant"), selection: $quadrant) {
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
            .navigationTitle(L("add.title"))
            .onChange(of: raw) { _, value in
                parsed = ParseEngine.parse(value)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("action.add"), action: add)
                        .disabled(parsed.title.isEmpty && parsed.issueKey == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("action.cancel")) { dismiss() }
                }
            }
        }
    }

    private func add() {
        let flags = quadrant.flags
        let title = parsed.title.isEmpty
            ? (parsed.issueKey ?? L("task.default.title"))
            : parsed.title
        let task = TaskItem(title: title,
                            isUrgent: flags.isUrgent,
                            isImportant: flags.isImportant,
                            links: parsed.links,
                            issueKey: parsed.issueKey,
                            weekStart: weekStart)
        context.insert(task)
        try? context.save()
        dismiss()
    }
}

#Preview {
    QuickAddView(defaultQuadrant: .urgentImportant, weekStart: Week.currentStart)
        .modelContainer(previewContainer)
}
