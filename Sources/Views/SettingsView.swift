import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LocalizationConfig.storageKey) private var language = AppLanguage.zhHans.rawValue
    @AppStorage("showCompleted") private var showCompleted = false
    @State private var rules: [ParseRule] = ParseRuleStore.load()

    var body: some View {
        NavigationStack {
            Form {
                Section(L("settings.language.section")) {
                    Picker(L("settings.language.section"), selection: $language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(L(lang.titleKey)).tag(lang.rawValue)
                        }
                    }
                    Text(L("settings.language.note"))
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section(L("settings.display.section")) {
                    Toggle(L("settings.showCompleted"), isOn: $showCompleted)
                }

                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("settings.parse.builtin"))
                        Text(L("settings.parse.builtin.desc"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($rules) { $rule in
                        NavigationLink {
                            RuleEditorView(rule: $rule)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name.isEmpty ? L("settings.rule.new") : rule.name)
                                if !rule.pattern.isEmpty {
                                    Text(rule.pattern)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .onDelete { rules.remove(atOffsets: $0) }
                    Button {
                        rules.append(ParseRule(name: "", pattern: "",
                                               issueGroup: 1, titleGroup: 2, linkGroup: 3))
                    } label: {
                        Label(L("settings.parse.addRule"), systemImage: "plus")
                    }
                } header: {
                    Text(L("settings.parse.section"))
                } footer: {
                    Text(L("settings.parse.hint"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(L("settings.title"))
            .onChange(of: rules) { _, new in ParseRuleStore.save(new) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("settings.done")) { dismiss() }
                }
            }
        }
    }
}

private struct RuleEditorView: View {
    @Binding var rule: ParseRule
    @State private var test = ""

    var body: some View {
        Form {
            Section(L("settings.rule.name")) {
                TextField(L("settings.rule.name"), text: $rule.name)
            }
            Section(L("settings.rule.section.regex")) {
                TextField(L("settings.rule.pattern"), text: $rule.pattern, axis: .vertical)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
            }
            Section {
                Stepper(value: $rule.issueGroup, in: 0...20) {
                    LabeledContent(L("settings.rule.issueGroup"), value: "\(rule.issueGroup)")
                }
                Stepper(value: $rule.titleGroup, in: 0...20) {
                    LabeledContent(L("settings.rule.titleGroup"), value: "\(rule.titleGroup)")
                }
                Stepper(value: $rule.linkGroup, in: 0...20) {
                    LabeledContent(L("settings.rule.linkGroup"), value: "\(rule.linkGroup)")
                }
            } header: {
                Text(L("settings.rule.section.groups"))
            } footer: {
                Text(L("settings.rule.groupNote"))
            }
            Section(L("settings.rule.section.test")) {
                TextField(L("settings.rule.testPlaceholder"), text: $test, axis: .vertical)
                    .frame(minHeight: 60)
                    .autocorrectionDisabled()
                RulePreview(rule: rule, text: test)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(rule.name.isEmpty ? L("settings.rule.new") : rule.name)
    }
}

private struct RulePreview: View {
    let rule: ParseRule
    let text: String

    var body: some View {
        let parsed = ParseEngine.apply(rule, to: text)
        if let parsed {
            if let key = parsed.issueKey {
                LabeledContent(L("add.preview.issueKey")) { IssueKeyBadge(key: key) }
            }
            if !parsed.title.isEmpty {
                LabeledContent(L("add.preview.title"), value: parsed.title)
            }
            ForEach(parsed.links, id: \.self) { LinkRow(urlString: $0) }
        } else if !text.isEmpty {
            Text(L("settings.rule.noMatch")).foregroundStyle(.secondary)
        }
    }
}
