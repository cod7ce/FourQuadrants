import SwiftUI
import SwiftData

/// 新建任务表单，支持「智能粘贴解析」：把整段工单文本拆成 工单号 / 标题 / 链接。
struct QuickAddView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let defaultQuadrant: Quadrant
    let weekStart: Date

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var raw = ""
    @State private var parsed = ParsedTaskInput(issueKey: nil, title: "", links: [])
    @State private var quadrant: Quadrant
    @State private var chosenTags: Set<Tag> = []
    @State private var newTagName = ""

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

                Section(L("detail.section.tags")) {
                    ForEach(allTags) { tag in
                        Button { toggle(tag) } label: {
                            HStack {
                                TagChip(tag: tag)
                                Spacer()
                                if chosenTags.contains(tag) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        TextField(L("detail.tag.new"), text: $newTagName)
                        Button(L("action.add"), action: addTag).disabled(newTagName.isEmpty)
                    }
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
                    Button(L("action.cancel")) {
                        context.rollback()   // 丢弃未保存的新标签
                        dismiss()
                    }
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
        task.tags = Array(chosenTags)
        context.insert(task)
        try? context.save()
        dismiss()
    }

    private func toggle(_ tag: Tag) {
        if chosenTags.contains(tag) { chosenTags.remove(tag) } else { chosenTags.insert(tag) }
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let hex = TagPalette.hexes[allTags.count % TagPalette.hexes.count]
        let tag = Tag(name: name, colorHex: hex)
        context.insert(tag)
        chosenTags.insert(tag)
        newTagName = ""
    }
}

#Preview {
    QuickAddView(defaultQuadrant: .urgentImportant, weekStart: Week.currentStart)
        .modelContainer(previewContainer)
}
