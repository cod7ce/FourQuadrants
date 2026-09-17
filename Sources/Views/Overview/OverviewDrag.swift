import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

// MARK: - 帧登记（把每行/每卡的 frame 收集到 "ov" 坐标空间）

/// 一行的落位插槽（顶层或子任务通用）。`quadrant` 为其所属象限（子任务取根祖先象限）。
struct OVSlot: Equatable {
    let uuid: String
    let quadrant: Quadrant
    let rect: CGRect
}
/// 象限卡片矩形（判断指针落在哪个象限）。
struct OVCard: Equatable {
    let quadrant: Quadrant
    let rect: CGRect
}

struct OVSlotKey: PreferenceKey {
    static let defaultValue: [OVSlot] = []
    static func reduce(value: inout [OVSlot], nextValue: () -> [OVSlot]) { value += nextValue() }
}
struct OVCardKey: PreferenceKey {
    static let defaultValue: [OVCard] = []
    static func reduce(value: inout [OVCard], nextValue: () -> [OVCard]) { value += nextValue() }
}

extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }
private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

/// 滚动几何快照（供边缘自动滚动读取偏移/内容高/视口高）。
struct ScrollGeom: Equatable { let offsetY: CGFloat; let contentH: CGFloat; let viewportH: CGFloat }

// MARK: - 拖拽状态模型

/// 松手时的落位目标。
enum OVTarget: Equatable {
    case insertBefore(String)   // 插到该 uuid 之前（同级重排；跨象限/跨层由 reorder 处理）
    case appendTo(Quadrant)     // 追加到该象限顶层末尾
    case nest(String)           // 嵌套为该 uuid 的子任务
}

@MainActor
@Observable
final class OverviewDrag {
    var slots: [OVSlot] = []
    var cards: [OVCard] = []
    /// 拖拽开始时冻结的行几何：命中判断/让位都用它，避免间隙一开就抖动。
    var frozen: [OVSlot] = []
    /// 拖拽开始时冻结的各象限卡高度：拖拽期间卡外框固定，避免格子跳动。
    var frozenCardH: [Quadrant: CGFloat] = [:]
    func frozenHeight(_ q: Quadrant) -> CGFloat? { frozenCardH[q] }

    var uuid: String?
    var task: TaskItem?
    var previewSize: CGSize = .zero
    var pointer: CGPoint = .zero
    var grab: CGSize = .zero
    var target: OVTarget?

    var isDragging: Bool { uuid != nil }
    var previewOrigin: CGPoint { CGPoint(x: pointer.x - grab.width, y: pointer.y - grab.height) }

    // 边缘自动滚动
    var viewportHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    var contentOffsetY: CGFloat = 0
    var scrollTo: ((CGFloat) -> Void)?
    private var ticker: Timer?

    private func startAutoscroll() {
        ticker?.invalidate()
        // 关键：拖拽时主 runloop 在 .eventTracking 模式，默认模式的定时器不触发；
        // 用 .common 模式（含 eventTracking）才能在拖拽过程中持续 tick。
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.autoscrollTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }
    private func stopAutoscroll() { ticker?.invalidate(); ticker = nil }

    private func autoscrollTick() {
        guard isDragging, viewportHeight > 0, let scrollTo else { return }
        let edge: CGFloat = 64
        let viewportY = pointer.y - contentOffsetY     // 指针在视口内的位置
        var raw: CGFloat = 0
        if viewportY < edge { raw = -(edge - viewportY) }
        else if viewportY > viewportHeight - edge { raw = viewportY - (viewportHeight - edge) }
        guard raw != 0 else { return }

        let speed = min(abs(raw), edge) / edge * 16    // 越靠边越快，最快 ~16px/帧
        let delta = raw < 0 ? -speed : speed
        let maxOffset = max(0, contentHeight - viewportHeight)
        let newY = min(max(0, contentOffsetY + delta), maxOffset)
        let applied = newY - contentOffsetY
        guard abs(applied) > 0.1 else { return }       // 已到顶/底

        contentOffsetY = newY                          // 乐观更新，下一帧几何回调再校正
        scrollTo(newY)
        pointer.y += applied                           // 内容滚动，指针在内容空间同步平移
        recompute()
    }

    func begin(_ task: TaskItem, at startLocation: CGPoint) {
        self.task = task; uuid = task.taskUUID
        frozen = slots            // 冻结开拖瞬间的几何
        frozenCardH = Dictionary(cards.map { ($0.quadrant, $0.rect.height) }, uniquingKeysWith: { a, _ in a })
        if let s = slots.first(where: { $0.uuid == task.taskUUID }) {
            previewSize = s.rect.size
            grab = CGSize(width: startLocation.x - s.rect.minX, height: startLocation.y - s.rect.minY)
        } else {
            previewSize = .zero; grab = .zero
        }
        pointer = startLocation
        recompute()
        startAutoscroll()
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    func move(_ p: CGPoint) {
        pointer = p
        let old = target
        recompute()
        #if os(macOS)
        if target != old, target != nil {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }

    func end() { stopAutoscroll(); uuid = nil; task = nil; target = nil; frozen = []; frozenCardH = [:] }

    /// 让位间隙的高度：统一为固定值（不随父/子行高变化），避免预占高度忽大忽小引起抖动。
    var gapHeight: CGFloat { 34 }

    private let insertMargin: CGFloat = 12   // 插入边界滞回：越线需多走这么多才切换

    private func recompute() {
        guard isDragging else { target = nil; return }
        guard let card = cards.first(where: { $0.rect.contains(pointer) })
            ?? cards.min(by: { dist($0.rect.center, pointer) < dist($1.rect.center, pointer) })
        else { target = nil; return }

        let q = card.quadrant
        let rows = frozen.filter { $0.quadrant == q && $0.uuid != uuid }
                         .sorted { $0.rect.minY < $1.rect.minY }
        guard !rows.isEmpty else { target = .appendTo(q); return }

        // 嵌套判定（滞回：进窄出宽——已在嵌套则更难退出，避免边界抖）
        for r in rows {
            let inNest = (target == .nest(r.uuid))
            let band = (inNest ? 0.20 : 0.32) * r.rect.height
            if pointer.y > r.rect.minY + band && pointer.y < r.rect.maxY - band {
                target = .nest(r.uuid); return
            }
        }

        // 插入序号（以当前目标为基准做滞回，越过某行中点需超出 insertMargin 才切换）
        let curIdx: Int
        switch target {
        case .insertBefore(let u): curIdx = rows.firstIndex { $0.uuid == u } ?? rawInsertIndex(rows)
        case .appendTo:            curIdx = rows.count
        default:                   curIdx = rawInsertIndex(rows)
        }
        var idx = min(curIdx, rows.count)
        while idx < rows.count && pointer.y > rows[idx].rect.midY + insertMargin { idx += 1 }
        while idx > 0 && pointer.y < rows[idx - 1].rect.midY - insertMargin { idx -= 1 }
        target = idx < rows.count ? .insertBefore(rows[idx].uuid) : .appendTo(q)
    }

    private func rawInsertIndex(_ rows: [OVSlot]) -> Int {
        rows.filter { pointer.y > $0.rect.midY }.count
    }
}

// MARK: - 悬浮预览行（跟手，1:1 复刻行内容）

struct OVDragPreview: View {
    @Environment(\.theme) private var theme
    let task: TaskItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: OverviewTaskRow.gap) {
            TaskCheckbox(isCompleted: task.isCompleted)
                .frame(minWidth: OverviewTaskRow.checkboxWidth)
            TaggedTitleText(task: task, strikethrough: false, underline: false, color: Color.appLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            DueDateLabel(task: task)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(theme.label.opacity(0.10), lineWidth: 1))   // 与象限 box 边框同色
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

// MARK: - 覆盖层：悬浮预览 + 插入指示

struct OverviewDragLayer: View {
    var drag: OverviewDrag

    var body: some View {
        ZStack(alignment: .topLeading) {
            if drag.isDragging {
                insertionIndicator
                if let task = drag.task {
                    OVDragPreview(task: task)
                        .frame(width: max(drag.previewSize.width, 40), alignment: .leading)
                        .scaleEffect(1.03)
                        .position(x: drag.previewOrigin.x + drag.previewSize.width / 2,
                                  y: drag.previewOrigin.y + drag.previewSize.height / 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: drag.target)
    }

    @ViewBuilder private var insertionIndicator: some View {
        switch drag.target {
        case .insertBefore(let uuid):
            if let s = drag.frozen.first(where: { $0.uuid == uuid }) {
                bar(x: s.rect.midX, y: s.rect.minY - 4, width: s.rect.width)
            }
        case .appendTo(let q):
            let rows = drag.frozen.filter { $0.quadrant == q && $0.uuid != drag.uuid }
            if let last = rows.max(by: { $0.rect.minY < $1.rect.minY }) {
                bar(x: last.rect.midX, y: last.rect.maxY + 4, width: last.rect.width)
            } else if let card = drag.cards.first(where: { $0.quadrant == q }) {
                bar(x: card.rect.midX, y: card.rect.minY + 64, width: card.rect.width - 32)
            }
        case .nest(let uuid):
            if let s = drag.frozen.first(where: { $0.uuid == uuid }) {
                // 目标行下方一条缩进的子插入条，示意「作为它的子任务」
                let indent = OverviewTaskRow.checkboxWidth + OverviewTaskRow.gap
                bar(x: s.rect.minX + indent + (s.rect.width - indent) / 2,
                    y: s.rect.maxY - 2, width: s.rect.width - indent)
            }
        case .none:
            EmptyView()
        }
    }

    private func bar(x: CGFloat, y: CGFloat, width: CGFloat) -> some View {
        Capsule().fill(Color.accentColor)
            .frame(width: max(width, 20), height: 3)
            .shadow(color: Color.accentColor.opacity(0.6), radius: 4)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }
}

// MARK: - 行拖拽手势（贴在具体一行上：父行只覆盖父行、子任务各覆盖自己）

struct OverviewRowGesture: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(OverviewDrag.self) private var drag
    let task: TaskItem
    let quadrant: Quadrant
    let week: Date

    private var isNestTarget: Bool { drag.target == .nest(task.taskUUID) }

    func body(content: Content) -> some View {
        content
            .background {
                if isNestTarget {   // 嵌套目标：填充高亮，明确「放进它里面」
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.16))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1))
                        .padding(.horizontal, -4).padding(.vertical, -2)
                }
            }
            .background(   // 登记本行原始几何（每行独立插槽）
                GeometryReader { g in
                    Color.clear.preference(
                        key: OVSlotKey.self,
                        value: [OVSlot(uuid: task.taskUUID, quadrant: quadrant, rect: g.frame(in: .named("ov")))])
                }
            )
            .gesture(dragGesture)
    }

    #if os(macOS)
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("ov"))
            .onChanged { d in
                if !drag.isDragging { drag.begin(task, at: d.startLocation) }
                drag.move(d.location)
            }
            .onEnded { d in
                drag.move(d.location); commit()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { drag.end() }
            }
    }
    #else
    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("ov")))
            .onChanged { value in
                if case .second(true, let d?) = value {
                    if !drag.isDragging { drag.begin(task, at: d.startLocation) }
                    drag.move(d.location)
                }
            }
            .onEnded { value in
                if case .second(_, let d?) = value { drag.move(d.location) }
                commit()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { drag.end() }
            }
    }
    #endif

    private func commit() {
        guard drag.uuid == task.taskUUID, let target = drag.target else { return }
        let anim = Animation.spring(response: 0.32, dampingFraction: 0.85)
        switch target {
        case .insertBefore(let uuid):
            guard let before = TaskMutations.task(uuid: uuid, in: context) else { return }
            let ordered = siblingList(of: before)
            withAnimation(anim) {
                TaskMutations.reorder(draggedUUID: task.taskUUID, before: before, ordered: ordered, in: context)
            }
        case .appendTo(let q):
            withAnimation(anim) {
                TaskMutations.place(uuid: task.taskUUID, into: q, before: nil, week: week, in: context)
            }
        case .nest(let uuid):
            if let parent = TaskMutations.task(uuid: uuid, in: context) {
                withAnimation(anim) { TaskMutations.makeChild(uuid: task.taskUUID, of: parent, in: context) }
            }
        }
    }

    /// 目标行的同级列表（用于 reorder 重编号）：子任务取其父的子列表，顶层取同象限/周的顶层活动任务。
    private func siblingList(of target: TaskItem) -> [TaskItem] {
        if let parent = target.parent { return parent.sortedSubtasks }
        let all = (try? context.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let f = target.quadrant.flags
        let wk = Week.start(of: target.weekStart)
        return all.filter {
            $0.parent == nil && !$0.isCompleted &&
            $0.isUrgent == f.isUrgent && $0.isImportant == f.isImportant &&
            Week.start(of: $0.weekStart) == wk
        }
    }
}

// MARK: - 块布局修饰器（贴在整块上：源块收拢、目标块上方让位）

struct OverviewRowLayout: ViewModifier {
    @Environment(OverviewDrag.self) private var drag
    let task: TaskItem

    private var isMe: Bool { drag.uuid == task.taskUUID }
    private var gapAbove: CGFloat {
        guard drag.isDragging, drag.uuid != task.taskUUID,
              case .insertBefore(let u)? = drag.target, u == task.taskUUID else { return 0 }
        return drag.gapHeight
    }
    /// 嵌套目标：在其块底部让出子任务的位置。
    private var gapBelow: CGFloat {
        guard drag.isDragging, drag.uuid != task.taskUUID,
              drag.target == .nest(task.taskUUID) else { return 0 }
        return drag.gapHeight
    }

    func body(content: Content) -> some View {
        content
            .opacity(isMe ? 0 : 1)                 // 源块收拢成「移走」（淡出即隐，无需裁剪）
            .frame(height: isMe ? 0 : nil)
            .padding(.top, gapAbove)               // 目标块上方让出间隙（插入）
            .padding(.bottom, gapBelow)            // 目标块下方让出间隙（嵌套为子）
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: gapAbove)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: gapBelow)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isMe)
    }
}

extension View {
    /// 条件套用一个修饰（条件为常量、不在运行时切换，避免视图身份抖动）。
    @ViewBuilder func modifierIf<V: View>(_ condition: Bool, _ transform: (Self) -> V) -> some View {
        if condition { transform(self) } else { self }
    }
    /// 行拖拽手势 + 帧登记（贴在具体一行上）。
    func overviewRowGesture(task: TaskItem, quadrant: Quadrant, week: Date) -> some View {
        modifier(OverviewRowGesture(task: task, quadrant: quadrant, week: week))
    }
    /// 源块收拢 / 目标块让位（贴在整块上）。
    func overviewRowLayout(task: TaskItem) -> some View {
        modifier(OverviewRowLayout(task: task))
    }
}
