import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 富文本辅助：在 RTFD（内嵌图片）与 NSAttributedString 间转换。
enum RichText {
    static func load(_ data: Data?) -> NSAttributedString {
        guard let data, !data.isEmpty else { return NSAttributedString() }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtfd
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil))
            ?? NSAttributedString()
    }

    static func data(_ string: NSAttributedString) -> Data? {
        guard string.length > 0 else { return nil }
        let range = NSRange(location: 0, length: string.length)
        let attrs: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtfd
        ]
        return try? string.data(from: range, documentAttributes: attrs)
    }
}

/// 持有当前富文本内容；编辑器随用户输入更新它，保存时由外部读取。
@Observable
final class RichContentStore {
    var attributed: NSAttributedString
    /// 外部重置（加载/取消）时递增，用于让编辑器把内容推回文本视图。
    private(set) var revision = 0

    init(_ data: Data? = nil) {
        attributed = RichText.load(data)
    }

    func reset(_ data: Data?) {
        attributed = RichText.load(data)
        revision += 1
    }
}

/// 可直接编辑的富文本区域：打字 + 直接粘贴图片（图文混排）。
struct RichTextEditor: View {
    let store: RichContentStore
    let isEditable: Bool

    var body: some View {
        _RichTextEditor(store: store, isEditable: isEditable)
    }
}

#if os(macOS)
private struct _RichTextEditor: NSViewRepresentable {
    let store: RichContentStore
    let isEditable: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        let tv = scroll.documentView as! NSTextView
        tv.isRichText = true
        tv.importsGraphics = true          // 允许粘贴/拖入图片
        tv.allowsImageEditing = true
        tv.allowsUndo = true
        tv.isEditable = isEditable
        tv.delegate = context.coordinator
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.textStorage?.setAttributedString(store.attributed)
        context.coordinator.textView = tv
        context.coordinator.lastRevision = store.revision
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        tv.isEditable = isEditable
        if context.coordinator.lastRevision != store.revision {
            tv.textStorage?.setAttributedString(store.attributed)
            context.coordinator.lastRevision = store.revision
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: RichContentStore
        weak var textView: NSTextView?
        var lastRevision = 0
        init(store: RichContentStore) { self.store = store }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView,
                  let ts = tv.textStorage else { return }
            store.attributed = NSAttributedString(attributedString: ts)
        }
    }
}
#else
private struct _RichTextEditor: UIViewRepresentable {
    let store: RichContentStore
    let isEditable: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.allowsEditingTextAttributes = true   // 允许粘贴图片为附件
        tv.isEditable = isEditable
        tv.isScrollEnabled = true
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.delegate = context.coordinator
        tv.attributedText = store.attributed
        context.coordinator.textView = tv
        context.coordinator.lastRevision = store.revision
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.isEditable = isEditable
        if context.coordinator.lastRevision != store.revision {
            tv.attributedText = store.attributed
            context.coordinator.lastRevision = store.revision
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let store: RichContentStore
        weak var textView: UITextView?
        var lastRevision = 0
        init(store: RichContentStore) { self.store = store }

        func textViewDidChange(_ tv: UITextView) {
            store.attributed = tv.attributedText
        }
    }
}
#endif
