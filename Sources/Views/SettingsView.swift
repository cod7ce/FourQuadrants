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
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)]) private var tags: [Tag]
    @Query private var allTasks: [TaskItem]
    @AppStorage(LocalizationConfig.storageKey) private var language = AppLanguage.zhHans.rawValue
    @AppStorage(AppFontSetting.key) private var appFontName = ""
    @AppStorage(ThemeManager.key) private var themeIDRaw = ThemeID.system.rawValue
    @AppStorage(InboxVisibility.key) private var showInbox = true
    @AppStorage(CompletedVisibility.key) private var hideCompleted = false
    #if os(macOS)
    @AppStorage(UIChromeConfig.opacityKey) private var uiOpacity = UIChromeConfig.defaultOpacity
    @AppStorage(UIChromeConfig.blurKey) private var uiBlur = UIChromeConfig.defaultBlur
    #endif
    @AppStorage(ParseRuleStore.builtinTagKey) private var builtinTag = ""
    @State private var rules: [ParseRule] = ParseRuleStore.load()
    @State private var editingTag: Tag?
    @State private var editingIsNew = false

    private func taskCount(_ tag: Tag) -> Int {
        allTasks.filter { $0.parent == nil && $0.tagList.contains { $0.name == tag.name } }.count
    }

    private func beginNewTag() {
        let t = Tag(name: "",
                    colorHex: TagPalette.hexes[tags.count % TagPalette.hexes.count],
                    sortOrder: (tags.map(\.sortOrder).max() ?? 0) + 1)
        context.insert(t)
        editingIsNew = true
        editingTag = t
    }

    private func moveTags(_ from: IndexSet, _ to: Int) {
        var arr = tags
        arr.move(fromOffsets: from, toOffset: to)
        for (i, t) in arr.enumerated() { t.sortOrder = Double(i) }
        try? context.save()
    }

    private func deleteTags(_ offsets: IndexSet) {
        for i in offsets { context.delete(tags[i]) }
        try? context.save()
    }

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

    #if os(macOS)
    /// 界面透明/模糊滑杆：带右侧百分比读数。
    private func chromeSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).appFont(.caption)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .appFont(.caption, monospaced: true).foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
        }
    }
    #endif

    @ViewBuilder private var appearanceSections: some View {
        Section(L("settings.language.section")) {
            Picker(L("settings.language.section"), selection: $language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(L(lang.titleKey)).tag(lang.rawValue)
                }
            }
            Text(L("settings.language.note")).appFont(.caption).foregroundStyle(.secondary)
        }
        Section {
            Picker(L("settings.theme.section"), selection: $themeIDRaw) {
                ForEach(ThemeID.allCases) { t in Text(L(t.titleKey)).tag(t.rawValue) }
            }
            Text(L("settings.theme.note")).appFont(.caption).foregroundStyle(.secondary)
            Toggle(L("settings.inbox.show"), isOn: $showInbox)
            Toggle(L("settings.completed.hide"), isOn: $hideCompleted)
            #if os(macOS)
            chromeSlider(L("settings.ui.opacity"), value: $uiOpacity)
            chromeSlider(L("settings.ui.blur"), value: $uiBlur)
            #endif
        } header: {
            Text(L("settings.theme.section"))
        }
        BackgroundSettingsSection()
        Section {
            Picker(L("settings.font.section"), selection: $appFontName) {
                Text(L("settings.font.system")).tag("")
                ForEach(fontFamilies, id: \.self) { fam in
                    Text(fam).font(.custom(fam, size: 13)).tag(fam)
                }
            }
            Text(L("settings.font.note")).appFont(.caption).foregroundStyle(.secondary)
        } header: {
            Text(L("settings.font.section"))
        }
        #if os(macOS)
        Section {
            HStack {
                Text(L("settings.update.current"))
                Spacer()
                Text("v\(Updater.shared.currentVersion)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Button(L("menu.checkUpdates")) {
                Task { await Updater.shared.checkForUpdates(silent: false) }
            }
        } header: {
            Text(L("settings.update.section"))
        }
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSections

                Section {
                    if tags.isEmpty {
                        Text(L("settings.tags.empty"))
                            .appFont(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            TagListRow(tag: tag, count: taskCount(tag)) {
                                editingIsNew = false; editingTag = tag
                            }
                        }
                        .onMove(perform: moveTags)
                        .onDelete(perform: deleteTags)
                    }
                    Button { beginNewTag() } label: {
                        Label(L("editor.tag.new"), systemImage: "plus")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("settings.tags.section")).appFont(.headline)
                        Text(L("settings.tags.subtitle")).appFont(.caption).foregroundStyle(.secondary)
                    }
                    .textCase(nil)
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
            .centeredWindow(item: $editingTag) { tag in
                TagEditorSheet(tag: tag, isNew: editingIsNew)
            }
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

/// 标签列表行：圆点 · 名称 · 右侧任务数；点击打开编辑弹窗（拖拽手柄由 List 悬停提供）。
private struct TagListRow: View {
    @Bindable var tag: Tag
    let count: Int
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Circle().fill(tag.color).frame(width: 16, height: 16)
                Text(tag.name.isEmpty ? L("detail.title.untitled") : tag.name)
                    .foregroundStyle(Color.appLabel)
                Spacer(minLength: 8)
                Text(String(format: L("settings.tags.count"), count))
                    .appFont(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 标签编辑弹窗：名称 + 常用颜色网格 + 预览 + 删除/完成。
struct TagEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismissSheet
    /// 放进独立窗口时由外部注入（见 CenteredWindow.swift）；sheet 里则为 nil。
    @Environment(\.closeHostWindow) private var closeHostWindow
    @Bindable var tag: Tag
    let isNew: Bool
    @State private var removed = false

    /// 关闭弹窗：独立窗口走关窗，sheet 走 dismiss。
    private func dismiss() {
        if let closeHostWindow { closeHostWindow() } else { dismissSheet() }
    }

    private var displayName: String {
        tag.name.isEmpty ? L("detail.title.untitled") : tag.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? L("editor.tag.new") : L("settings.tags.edit"))
                .appFont(.headline)

            HStack(spacing: 10) {
                Circle().fill(tag.color).frame(width: 14, height: 14)
                TextField(L("settings.tags.name"), text: $tag.name)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.appFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.25)))

            Text(L("settings.tags.color"))
                .appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                ForEach(TagPalette.hexes, id: \.self) { swatch($0) }
            }

            HStack(spacing: 10) {
                Text(L("settings.tags.preview")).appFont(.caption).foregroundStyle(.secondary)
                TagChip(tag: tag)
                Text(displayName)
                    .appFont(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(tag.color))
                    .foregroundStyle(tag.color)
            }

            Divider()

            HStack {
                Button(role: .destructive) { deleteTag() } label: {
                    Text(L("settings.tags.delete"))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                Spacer()
                Button(L("settings.done")) { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear {
            // 关闭时若名称为空则丢弃（新建取消或清空名称）
            if !removed, tag.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.delete(tag)
            }
            try? context.save()
        }
    }

    private func swatch(_ hex: String) -> some View {
        let selected = tag.colorHex == hex
        return Button {
            tag.colorHex = hex
        } label: {
            Circle().fill(Color(hex: hex) ?? .blue)
                .frame(width: 34, height: 34)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: selected ? 2 : 0)
                    .padding(-3))
        }
        .buttonStyle(.plain)
    }

    private func deleteTag() {
        removed = true
        context.delete(tag)
        try? context.save()
        dismiss()
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
