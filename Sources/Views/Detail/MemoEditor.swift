import SwiftUI
import SwiftData
import RichTextKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 备忘编辑器默认样式（行高/内边距固定；字号在设置里可调）。
enum MemoStyle {
    // 关键：背景高亮填充的是「行框」。lineHeightMultiple / minimumLineHeight /
    // paragraphSpacingBefore 都会被算进行框、被背景填充 → 高亮变高、文字偏上或偏下。
    // 只有「段后 paragraphSpacing」和「行后 lineSpacing」不被填充。
    // 所以这里只用段后/行后间距：高亮框紧贴文字（文字天然居中），行间留白由
    // 上一行的「段后」提供。
    static let paragraphSpaceRatio: CGFloat = 0.70  // 段后留白 = 字号 × 该比例
    static let lineSpacingRatio: CGFloat = 0.30     // 段内软换行的行间距
    static let inset: CGFloat = 14             // 文本容器内边距（上下左右）
    static let horizontalPadding: CGFloat = 16 // 编辑器外层左右留白
    static let defaultFontSize: Double = 15

    /// 按当前字号设置默认段落间距，可在已有样式上调整以保留对齐。
    static func applyDefaultSpacing(_ p: NSMutableParagraphStyle, fontSize: Double) {
        let fs = CGFloat(fontSize)
        p.paragraphSpacing = fs * paragraphSpaceRatio   // 段后留白（不被高亮填充）
        p.lineSpacing = fs * lineSpacingRatio
        // 清掉一切会撑高「行框」从而把高亮拉高的设置
        p.paragraphSpacingBefore = 0
        p.lineHeightMultiple = 0
        p.minimumLineHeight = 0
        p.maximumLineHeight = 0
    }
}

/// 荧光笔配色：色板显示用亮色，实际涂到文字背后时降透明（像真马克笔，不挡字）。
enum MemoHighlight {
    static let yellow = Color(red: 1.00, green: 0.94, blue: 0.20)
    static let green  = Color(red: 0.50, green: 1.00, blue: 0.30)
    static let blue   = Color(red: 0.30, green: 0.85, blue: 1.00)
    static let pink   = Color(red: 1.00, green: 0.42, blue: 0.78)
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.18)
    static let appliedOpacity: Double = 0.45   // 实际高亮的透明度
}

/// 每周备忘：用社区库 RichTextKit 的富文本编辑器（WYSIWYG，跨 iOS/macOS）。
/// 数据以 RTFD 存（复用 RichText.load/data，保留字体/颜色/下划线/图片）。
struct MemoEditor: View {
    @Environment(\.modelContext) private var modelContext
    let weekStart: Date

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("memoFontSize") private var memoFontSize = MemoStyle.defaultFontSize
    @Query(sort: \WeekNote.weekStart) private var notes: [WeekNote]
    @State private var text = NSAttributedString(string: "")
    @StateObject private var rtContext = RichTextKit.RichTextContext()
    @StateObject private var holder = RichTextViewHolder()
    @State private var saveWork: DispatchWorkItem?

    private func note(_ week: Date) -> WeekNote? {
        notes.first { Week.same($0.weekStart, week) }
    }

    /// 备忘编辑器的默认样式：字号 / 行高 / 内边距（在 setup 之后最后调用，确保生效）。
    private func configureEditor(_ component: RichTextViewComponent) {
        // 图片：只按「宽度」限制到内容区域，高度不限制（避免矮面板把图片按高度压缩、
        // 连带拉宽）。实际宽小于内容宽的图片保持原始大小，更大的等比缩到内容宽。
        component.imageConfiguration = RichTextImageConfiguration(
            pasteConfiguration: .enabled,
            dropConfiguration: .enabled,
            maxImageSize: (width: .frame, height: .points(100_000))
        )

        let para = NSMutableParagraphStyle()
        MemoStyle.applyDefaultSpacing(para, fontSize: memoFontSize)
        #if os(macOS)
        guard let tv = component as? NSTextView else { return }
        let font = NSFont.systemFont(ofSize: CGFloat(memoFontSize))
        tv.isAutomaticLinkDetectionEnabled = true
        tv.textContainerInset = NSSize(width: MemoStyle.inset, height: MemoStyle.inset)
        tv.font = font
        tv.defaultParagraphStyle = para
        tv.typingAttributes = [.font: font, .paragraphStyle: para, .foregroundColor: NSColor.textColor]
        #else
        guard let tv = component as? UITextView else { return }
        let font = UIFont.systemFont(ofSize: CGFloat(memoFontSize))
        tv.dataDetectorTypes = .link
        tv.textContainerInset = UIEdgeInsets(top: MemoStyle.inset, left: MemoStyle.inset,
                                             bottom: MemoStyle.inset, right: MemoStyle.inset)
        tv.font = font
        tv.typingAttributes = [.font: font, .paragraphStyle: para, .foregroundColor: UIColor.label]
        #endif
    }


    var body: some View {
        VStack(spacing: 0) {
            MemoToolbar(context: rtContext, holder: holder, onContentChanged: { scheduleSave() })
            Divider()
            RichTextKit.RichTextEditor(text: $text, context: rtContext) { component in
                holder.component = component
                configureEditor(component)
            }
            .richTextEditorStyle(.init(font: .systemFont(ofSize: CGFloat(memoFontSize))))
            .id(memoFontSize)   // 改字号时重建编辑器以重新套用默认样式
            .focusedValue(\.richTextContext, rtContext)
            .padding(.horizontal, MemoStyle.horizontalPadding)
            .padding(.bottom, 8)
        }
        .background(.background)
        .onAppear { pushIntoEditor(load(weekStart)) }
        .onChange(of: weekStart) { oldWeek, newWeek in
            saveNow(to: oldWeek)
            pushIntoEditor(load(newWeek))
        }
        .onChange(of: text.string) { _, _ in
            scheduleSave()    // 打字内容变化即保存
            scheduleRefit()   // 粘贴图片后归正其尺寸
        }
        .onReceive(rtContext.objectWillChange) { _ in scheduleSave() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveNow(to: weekStart) }   // 失活/退后台/退出前立即保存
        }
    }

    /// 把内容真正推进底层文本视图（RichTextKit 的 text 绑定不会更新视图，
    /// 必须经 context.setAttributedString → setRichText 才会显示）。
    private func pushIntoEditor(_ content: NSAttributedString) {
        text = content
        DispatchQueue.main.async {
            rtContext.setAttributedString(to: content)
            // 推入后重新套用默认排版（行高/字号），保证新输入也一致
            if let comp = holder.component { configureEditor(comp) }
            scheduleRefit()   // 等布局完成后归正图片尺寸
        }
    }

    private func load(_ week: Date) -> NSAttributedString {
        let base = note(week)?.content.map { RichText.load($0) } ?? NSAttributedString(string: "")
        // 给全文统一套行间距（保留各段已有对齐等），新输入也用同样的行距
        let mutable = NSMutableAttributedString(attributedString: base)
        let full = NSRange(location: 0, length: mutable.length)
        var updates: [(NSRange, NSMutableParagraphStyle)] = []
        mutable.enumerateAttribute(.paragraphStyle, in: full) { value, range, _ in
            let p = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            MemoStyle.applyDefaultSpacing(p, fontSize: memoFontSize)
            updates.append((range, p))
        }
        for (range, p) in updates { mutable.addAttribute(.paragraphStyle, value: p, range: range) }
        return mutable
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { saveNow(to: weekStart) }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    // MARK: - 图片尺寸归正

    /// 计算内容区域可用宽度（去掉文本容器左右内边距）。未完成布局时返回 nil。
    #if os(macOS)
    private func usableWidth(_ tv: NSTextView) -> CGFloat? {
        let pad = tv.textContainer?.lineFragmentPadding ?? 5
        let w = (tv.textContainer?.size.width ?? tv.bounds.width) - 2 * pad
        return w > 60 ? w : nil
    }
    #else
    private func usableWidth(_ tv: UITextView) -> CGFloat? {
        let pad = tv.textContainer.lineFragmentPadding
        let raw = tv.textContainer.size.width
        let base = (raw.isFinite && raw > 0) ? raw : tv.bounds.width
        let w = base - 2 * pad
        return w > 60 ? w : nil
    }
    #endif

    /// 目标尺寸：实际宽 < 内容宽 → 原始大小；否则等比缩到内容宽。
    /// 保留用户手动调过的较小尺寸（仅当当前显示宽超过内容宽或超过原图宽时才归正）。
    private func fittedSize(actual: CGSize, current: CGSize, maxWidth: CGFloat) -> CGSize? {
        guard actual.width > 0, maxWidth > 0 else { return nil }
        let cur = current.width
        let needs = cur <= 0 || cur > maxWidth + 0.5 || cur > actual.width + 0.5
        guard needs else { return nil }
        let w = min(actual.width, maxWidth)
        let h = actual.height * (w / actual.width)
        if abs(cur - w) < 0.5 { return nil }
        return CGSize(width: w, height: h)
    }

    private func scheduleRefit() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { refitImages() }
    }

    /// 遍历所有图片附件，按规则归正其显示尺寸。
    private func refitImages() {
        #if os(macOS)
        guard let tv = holder.component as? NSTextView, let storage = tv.textStorage,
              let maxW = usableWidth(tv) else { return }
        #else
        guard let tv = holder.component as? UITextView, let storage = tv.textStorage as NSTextStorage?,
              let maxW = usableWidth(tv) else { return }
        #endif
        let full = NSRange(location: 0, length: storage.length)
        var edits: [(NSRange, NSTextAttachment, CGSize)] = []
        storage.enumerateAttribute(.attachment, in: full) { obj, range, _ in
            guard let att = obj as? NSTextAttachment, let img = att.attachedImage else { return }
            if let target = fittedSize(actual: img.size, current: att.bounds.size, maxWidth: maxW) {
                edits.append((range, att, target))
            }
        }
        guard !edits.isEmpty else { return }
        storage.beginEditing()
        for (range, att, size) in edits {
            att.bounds = CGRect(origin: .zero, size: size)
            storage.removeAttribute(.attachment, range: range)
            storage.addAttribute(.attachment, value: att, range: range)
        }
        storage.endEditing()
        #if os(macOS)
        if let tc = tv.textContainer { tv.layoutManager?.ensureLayout(for: tc) }
        tv.needsDisplay = true
        #else
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        tv.setNeedsDisplay()
        #endif
        scheduleSave()
    }

    /// 直接读底层文本视图的当前内容（比 text 绑定更可靠）。
    private func currentContent() -> NSAttributedString {
        #if os(macOS)
        return (holder.component as? NSTextView)?.attributedString() ?? text
        #else
        return (holder.component as? UITextView)?.attributedText ?? text
        #endif
    }

    private func saveNow(to week: Date) {
        let content = currentContent()
        let data = RichText.data(content)
        if let note = note(week) {
            note.content = data
        } else if content.length > 0 {
            let newNote = WeekNote(weekStart: Week.start(of: week))
            newNote.content = data
            modelContext.insert(newNote)
        }
        try? modelContext.save()
    }
}

/// 持有底层富文本视图组件，供工具栏对「选中范围」直接设属性。
final class RichTextViewHolder: ObservableObject {
    weak var component: RichTextViewComponent?
}

/// 自定义紧凑工具栏：自己的图标，通过 RichTextContext 作用到编辑器。
private struct MemoToolbar: View {
    @ObservedObject var context: RichTextKit.RichTextContext
    let holder: RichTextViewHolder
    var onContentChanged: () -> Void = {}

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Text(L("memo.section")).font(.headline)
                Divider().frame(height: 16)

                styleButton(.bold, "bold", L("memo.bold"))
                styleButton(.italic, "italic", L("memo.italic"))
                styleButton(.underlined, "underline", L("memo.underline"))
                styleButton(.strikethrough, "strikethrough", L("memo.strike"))

                Divider().frame(height: 16)
                iconButton("textformat.size.smaller", L("memo.fontSmaller")) {
                    context.handle(.stepFontSize(points: -1))
                }
                iconButton("textformat.size.larger", L("memo.fontLarger")) {
                    context.handle(.stepFontSize(points: 1))
                }

                Divider().frame(height: 16)
                iconButton("text.alignleft", L("memo.alignLeft")) { setAlignment(.left) }
                iconButton("text.aligncenter", L("memo.alignCenter")) { setAlignment(.center) }
                iconButton("text.alignright", L("memo.alignRight")) { setAlignment(.right) }

                Divider().frame(height: 16)
                Image(systemName: "highlighter").foregroundStyle(.secondary)
                swatch(nil, false, L("memo.color.default"))
                swatch(.red, false, L("memo.color.red"))
                swatch(.orange, false, L("memo.color.orange"))
                swatch(.yellow, false, L("memo.color.yellow"))
                swatch(.green, false, L("memo.color.green"))
                swatch(.blue, false, L("memo.color.blue"))
                swatch(.purple, false, L("memo.color.purple"))

                Divider().frame(height: 16)
                Image(systemName: "paintbrush").foregroundStyle(.secondary)
                swatch(nil, true, L("memo.highlight.none"))
                swatch(MemoHighlight.yellow, true, L("memo.color.yellow"))
                swatch(MemoHighlight.green, true, L("memo.color.green"))
                swatch(MemoHighlight.blue, true, L("memo.color.blue"))
                swatch(MemoHighlight.pink, true, L("memo.color.pink"))
                swatch(MemoHighlight.orange, true, L("memo.color.orange"))

                Divider().frame(height: 16)
                iconButton("eraser", L("memo.clear")) { clearFormatting() }

                // 选中图片时，出现尺寸调节
                if let sel = selectedAttachment {
                    Divider().frame(height: 16)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                    iconButton("minus.magnifyingglass", L("memo.image.smaller")) { scaleImage(0.85, sel) }
                    iconButton("plus.magnifyingglass", L("memo.image.larger")) { scaleImage(1 / 0.85, sel) }
                    iconButton("arrow.up.left.and.arrow.down.right", L("memo.image.fit")) { fitImage(sel) }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func styleButton(_ style: RichTextStyle, _ symbol: String, _ help: String) -> some View {
        let active = context.hasStyle(style)
        return Button { context.toggleStyle(style) } label: {
            Image(systemName: symbol)
                .frame(width: 24, height: 22)
                .background(active ? Color.accentColor.opacity(0.2) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(active ? Color.accentColor : .primary)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func iconButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func swatch(_ color: Color?, _ isHighlight: Bool, _ help: String) -> some View {
        let display = color ?? (isHighlight ? Color.clear : Color.primary)
        return Button {
            applyColor(color, isHighlight: isHighlight)
        } label: {
            Circle()
                .fill(display)
                .frame(width: 15, height: 15)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.5)))
                .overlay {
                    if color == nil && isHighlight {
                        Image(systemName: "line.diagonal")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// 只对当前选区设色，不改 typing 属性（之后输入恢复普通样式）。
    private func applyColor(_ color: Color?, isHighlight: Bool) {
        guard let comp = holder.component else { return }
        let range = comp.selectedRange
        guard range.length > 0 else { return }
        let target: RichTextColor = isHighlight ? .background : .foreground
        let value: ColorRepresentable
        if let color {
            // 荧光高亮降透明，像真马克笔；前景文字色保持不透明
            value = colorRep(isHighlight ? color.opacity(MemoHighlight.appliedOpacity) : color)
        } else {
            value = isHighlight ? clearColor : defaultText
        }
        comp.setRichTextColor(target, to: value, at: range)
    }

    /// 清除选区的字符格式：还原常规字体（去粗体/斜体，保留字号）、去下划线/
    /// 删除线/高亮背景，文字色复位。直接操作 textStorage，确保可靠。
    private func clearFormatting() {
        #if os(macOS)
        guard let tv = holder.component as? NSTextView, let storage = tv.textStorage else { return }
        #else
        guard let tv = holder.component as? UITextView, let storage = tv.textStorage as NSTextStorage? else { return }
        #endif
        let range = tv.selectedRange
        guard range.length > 0, range.location + range.length <= storage.length else { return }
        storage.beginEditing()
        storage.removeAttribute(.underlineStyle, range: range)
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.removeAttribute(.backgroundColor, range: range)
        storage.addAttribute(.foregroundColor, value: defaultText, range: range)
        // 逐段把字体还原为常规系统字体（保留各自字号）
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            #if os(macOS)
            let size = (value as? NSFont)?.pointSize ?? CGFloat(MemoStyle.defaultFontSize)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size), range: sub)
            #else
            let size = (value as? UIFont)?.pointSize ?? CGFloat(MemoStyle.defaultFontSize)
            storage.addAttribute(.font, value: UIFont.systemFont(ofSize: size), range: sub)
            #endif
        }
        storage.endEditing()
        #if os(macOS)
        tv.needsDisplay = true
        #else
        tv.setNeedsDisplay()
        #endif
        onContentChanged()
    }

    // MARK: - 图片手动调节

    /// 当前选区内的图片附件（取第一个）。
    private var selectedAttachment: (NSTextAttachment, NSRange)? {
        #if os(macOS)
        guard let tv = holder.component as? NSTextView, let storage = tv.textStorage else { return nil }
        let r = tv.selectedRange
        #else
        guard let tv = holder.component as? UITextView, let storage = tv.textStorage as NSTextStorage? else { return nil }
        let r = tv.selectedRange
        #endif
        guard r.length >= 1, r.location + r.length <= storage.length else { return nil }
        var result: (NSTextAttachment, NSRange)?
        storage.enumerateAttribute(.attachment, in: r) { obj, range, stop in
            if let att = obj as? NSTextAttachment, att.attachedImage != nil {
                result = (att, range); stop.pointee = true
            }
        }
        return result
    }

    private func imageMaxWidth() -> CGFloat {
        #if os(macOS)
        guard let tv = holder.component as? NSTextView else { return 400 }
        let pad = tv.textContainer?.lineFragmentPadding ?? 5
        return max(60, (tv.textContainer?.size.width ?? tv.bounds.width) - 2 * pad)
        #else
        guard let tv = holder.component as? UITextView else { return 400 }
        let pad = tv.textContainer.lineFragmentPadding
        let raw = tv.textContainer.size.width
        let base = (raw.isFinite && raw > 0) ? raw : tv.bounds.width
        return max(60, base - 2 * pad)
        #endif
    }

    private func scaleImage(_ factor: CGFloat, _ sel: (NSTextAttachment, NSRange)) {
        let (att, _) = sel
        guard let img = att.attachedImage, img.size.width > 0 else { return }
        let cur = att.bounds.width > 0 ? att.bounds.width : img.size.width
        let w = min(max(40, cur * factor), imageMaxWidth())
        applyImageWidth(w, to: sel, image: img)
    }

    private func fitImage(_ sel: (NSTextAttachment, NSRange)) {
        let (att, _) = sel
        guard let img = att.attachedImage, img.size.width > 0 else { return }
        applyImageWidth(min(img.size.width, imageMaxWidth()), to: sel, image: img)
    }

    private func applyImageWidth(_ w: CGFloat, to sel: (NSTextAttachment, NSRange), image img: ImageRepresentable) {
        let (att, range) = sel
        let h = img.size.height * (w / img.size.width)
        att.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        #if os(macOS)
        guard let tv = holder.component as? NSTextView, let storage = tv.textStorage else { return }
        #else
        guard let tv = holder.component as? UITextView, let storage = tv.textStorage as NSTextStorage? else { return }
        #endif
        storage.beginEditing()
        storage.removeAttribute(.attachment, range: range)
        storage.addAttribute(.attachment, value: att, range: range)
        storage.endEditing()
        #if os(macOS)
        if let tc = tv.textContainer { tv.layoutManager?.ensureLayout(for: tc) }
        tv.needsDisplay = true
        #else
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        tv.setNeedsDisplay()
        #endif
        onContentChanged()
    }

    // MARK: - 对齐（仅当前段落，不带到别处）

    private func setAlignment(_ alignment: NSTextAlignment) {
        #if os(macOS)
        guard let tv = holder.component as? NSTextView, let storage = tv.textStorage else { return }
        #else
        guard let tv = holder.component as? UITextView, let storage = tv.textStorage as NSTextStorage? else { return }
        #endif
        let ns = storage.string as NSString
        let para = ns.paragraphRange(for: tv.selectedRange)
        storage.beginEditing()
        if para.length > 0 {
            storage.enumerateAttribute(.paragraphStyle, in: para) { value, range, _ in
                // 复制现有段落样式（保留行距等），仅改对齐
                let p = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                    ?? NSMutableParagraphStyle()
                p.alignment = alignment
                storage.addAttribute(.paragraphStyle, value: p, range: range)
            }
        }
        storage.endEditing()
        // 把输入属性的对齐重置为默认，避免换行/移动到别的行后还沿用此对齐
        var typing = tv.typingAttributes
        let tp = ((typing[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        tp.alignment = .natural
        typing[.paragraphStyle] = tp
        tv.typingAttributes = typing
        #if os(macOS)
        if let tc = tv.textContainer { tv.layoutManager?.ensureLayout(for: tc) }
        tv.needsDisplay = true
        #else
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        tv.setNeedsDisplay()
        #endif
        onContentChanged()
    }

    private func colorRep(_ color: Color) -> ColorRepresentable {
        #if os(macOS)
        NSColor(color)
        #else
        UIColor(color)
        #endif
    }

    private var defaultText: ColorRepresentable {
        #if os(macOS)
        NSColor.textColor
        #else
        UIColor.label
        #endif
    }

    private var clearColor: ColorRepresentable {
        #if os(macOS)
        NSColor.clear
        #else
        UIColor.clear
        #endif
    }
}
