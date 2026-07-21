import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage(LocalizationConfig.storageKey) private var language = AppLanguage.zhHans.rawValue
    @AppStorage(AppFontSetting.key) private var appFontName = ""
    @AppStorage(ParseRuleStore.builtinTagKey) private var builtinTag = ""
    @State private var rules: [ParseRule] = ParseRuleStore.load()

    /// 行内快速切换「自动标签」的下拉菜单。
    @ViewBuilder
    private func tagMenu(_ selection: Binding<String>) -> some View {
        Menu {
            Button(L("settings.rule.tag.none")) { selection.wrappedValue = "" }
            if !tags.isEmpty { Divider() }
            ForEach(tags) { t in
                Button {
                    selection.wrappedValue = t.name
                } label: {
                    Label(t.name, systemImage: selection.wrappedValue == t.name ? "checkmark" : "tag")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(selection.wrappedValue.isEmpty ? L("settings.rule.tag.none") : selection.wrappedValue)
                    .appFont(.caption)
                    .foregroundStyle(selection.wrappedValue.isEmpty ? .secondary : .primary)
                Image(systemName: "chevron.up.chevron.down").imageScale(.small).foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
    }

    private var fontFamilies: [String] {
        #if os(macOS)
        return NSFontManager.shared.availableFontFamilies.sorted()
        #else
        return UIFont.familyNames.sorted()
        #endif
    }

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
                        .appFont(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Picker(L("settings.font.section"), selection: $appFontName) {
                        Text(L("settings.font.system")).tag("")
                        ForEach(fontFamilies, id: \.self) { fam in
                            Text(fam).font(.custom(fam, size: 13)).tag(fam)
                        }
                    }
                    Text(L("settings.font.note"))
                        .appFont(.caption).foregroundStyle(.secondary)
                } header: {
                    Text(L("settings.font.section"))
                }

                Section {
                    if tags.isEmpty {
                        Text(L("settings.tags.empty"))
                            .appFont(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in TagEditRow(tag: tag) }
                            .onDelete { offsets in
                                for i in offsets { context.delete(tags[i]) }
                                try? context.save()
                            }
                    }
                } header: {
                    Text(L("settings.tags.section"))
                } footer: {
                    Text(L("settings.tags.note")).appFont(.caption)
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("settings.parse.builtin"))
                            Text(L("settings.parse.builtin.desc"))
                                .appFont(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        tagMenu($builtinTag)
                    }
                    ForEach($rules) { $rule in
                        HStack {
                            NavigationLink {
                                RuleEditorView(rule: $rule)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.name.isEmpty ? L("settings.rule.new") : rule.name)
                                    if !rule.pattern.isEmpty {
                                        Text(rule.pattern)
                                            .appFont(.caption, monospaced: true)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            tagMenu($rule.tagName)
                            Button(role: .destructive) {
                                rules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                            .help(L("settings.rule.delete"))
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
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("settings.done")) { dismiss() }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }
}

/// 标签管理行：改名（文本框）、换色（调色板圆点）、右侧实时预览。
private struct TagEditRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var tag: Tag

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(L("settings.tags.name"), text: $tag.name)
                    .onChange(of: tag.name) { _, _ in save() }
                Spacer()
                TagChip(tag: tag)   // 实时预览
            }
            HStack(spacing: 8) {
                ForEach(TagPalette.hexes, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .blue)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(Color.primary,
                                                       lineWidth: tag.colorHex == hex ? 2 : 0))
                        .contentShape(Circle())
                        .onTapGesture { tag.colorHex = hex; save() }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func save() { try? context.save() }
}

private struct RuleEditorView: View {
    @Binding var rule: ParseRule
    @State private var test = ""

    var body: some View {
        Form {
            Section(L("settings.rule.name")) {
                TextField(L("settings.rule.name"), text: $rule.name)
            }
            Section {
                TextField(L("settings.rule.tag.placeholder"), text: $rule.tagName)
                    .autocorrectionDisabled()
            } header: {
                Text(L("settings.rule.tag"))
            } footer: {
                Text(L("settings.rule.tag.note"))
            }
            Section(L("settings.rule.section.regex")) {
                TextField(L("settings.rule.pattern"), text: $rule.pattern, axis: .vertical)
                    .appFont(.body, monospaced: true)
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
