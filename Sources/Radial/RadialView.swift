import AppKit
import SwiftUI

public enum RadialAction: Hashable {
    case convert(FileFormat)
    case tool(ToolID)
    case fileAction(FileAction)
}

public struct RadialItem: Identifiable, Hashable {
    public let action: RadialAction
    public let label: String
    public let detail: String
    public let symbol: String

    public var id: RadialAction { action }

    public init(fileAction: FileAction) {
        action = .fileAction(fileAction)
        label = fileAction.title
        detail = fileAction.rawValue
        symbol = fileAction.symbol
    }

    public init(format: FileFormat) {
        action = .convert(format)
        label = format.displayName
        detail = "Convert to \(format.displayName)"
        symbol = format.category.symbol
    }

    public init(tool: ToolID) {
        action = .tool(tool)
        label = tool.radialLabel
        detail = tool.title
        symbol = tool.symbol
    }

    public var category: FormatCategory? {
        switch action {
        case .convert(let format): return format.category
        case .tool(let tool): return tool.categories.first
        case .fileAction: return nil
        }
    }
}

public enum RadialPastel {
    public static let palette: [Color] = [
        Color(red: 1.00, green: 0.65, blue: 0.62), // Soft Coral / Rose
        Color(red: 1.00, green: 0.77, blue: 0.55), // Soft Peach / Warm Apricot
        Color(red: 0.98, green: 0.88, blue: 0.54), // Soft Butter / Warm Honey
        Color(red: 0.58, green: 0.88, blue: 0.72), // Soft Mint / Sage
        Color(red: 0.54, green: 0.82, blue: 0.98), // Soft Sky / Azure
        Color(red: 0.68, green: 0.73, blue: 1.00), // Soft Periwinkle
        Color(red: 0.86, green: 0.70, blue: 0.96), // Soft Lilac / Orchid
        Color(red: 1.00, green: 0.70, blue: 0.84), // Soft Blush / Rosewater
    ]

    public static func color(for index: Int, total: Int, category: FormatCategory? = nil) -> Color {
        if let category = category {
            switch category {
            case .image: return Color(red: 1.00, green: 0.65, blue: 0.62)
            case .video: return Color(red: 0.54, green: 0.82, blue: 0.98)
            case .audio: return Color(red: 0.68, green: 0.73, blue: 1.00)
            case .document: return Color(red: 0.86, green: 0.70, blue: 0.96)
            case .spreadsheet: return Color(red: 0.58, green: 0.88, blue: 0.72)
            case .subtitle: return Color(red: 1.00, green: 0.77, blue: 0.55)
            case .archive: return Color(red: 0.98, green: 0.88, blue: 0.54)
            }
        }
        return palette[index % palette.count]
    }
}

public struct IndexedRadialItem: Identifiable {
    public let index: Int
    public let item: RadialItem
    public var id: RadialAction { item.action }

    public init(index: Int, item: RadialItem) {
        self.index = index
        self.item = item
    }
}

public struct RadialPetalView: View {
    public let item: RadialItem
    public let index: Int
    public let isHighlighted: Bool
    public let geometry: RadialGeometry
    public let totalCount: Int
    public let wheelDiameter: CGFloat

    private var midpoint: CGPoint {
        geometry.midpoint(
            for: index,
            in: CGRect(x: 0, y: 0, width: wheelDiameter, height: wheelDiameter)
        )
    }

    public var body: some View {
        let pastel = RadialPastel.color(for: index, total: totalCount, category: item.category)

        ZStack {
            if isHighlighted {
                WedgeShape(geometry: geometry, index: index)
                    .fill(
                        LinearGradient(
                            colors: [pastel.opacity(0.95), pastel.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: pastel.opacity(0.55), radius: 10, x: 0, y: 0)
                    .overlay(
                        WedgeShape(geometry: geometry, index: index)
                            .stroke(Color.white.opacity(0.90), lineWidth: 1.8)
                    )
            } else {
                WedgeShape(geometry: geometry, index: index)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .windowBackgroundColor).opacity(0.48),
                                pastel.opacity(0.24)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        WedgeShape(geometry: geometry, index: index)
                            .stroke(pastel.opacity(0.40), lineWidth: 1.0)
                    )
            }

            VStack(spacing: 2) {
                Image(systemName: item.symbol)
                    .font(.system(size: totalCount > 8 ? 13 : 15, weight: .semibold))
                    .foregroundStyle(isHighlighted ? Color.white : pastel.opacity(0.95))
                    .shadow(color: isHighlighted ? Color.black.opacity(0.25) : Color.clear, radius: 2)

                Text(item.label)
                    .font(.system(size: totalCount > 8 ? 9 : 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                    .shadow(color: isHighlighted ? Color.black.opacity(0.25) : Color.clear, radius: 2)
            }
            .frame(width: max(32, geometry.labelWidth))
            .position(x: midpoint.x, y: midpoint.y)
        }
        .frame(width: wheelDiameter, height: wheelDiameter)
    }
}

public struct RadialWheelView: View {
    public var presentationID: UUID
    public var items: [RadialItem]
    public var highlighted: Int?
    public var title: String
    public var emptyMessage: String
    public var emptyDetail: String
    public var geometry: RadialGeometry
    public var mode: RadialMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public var animateEntrance: Bool = true
    @SwipState private var scale: CGFloat = 0.85
    @SwipState private var opacity: Double = 0

    public init(
        presentationID: UUID,
        items: [RadialItem],
        highlighted: Int?,
        title: String,
        emptyMessage: String,
        emptyDetail: String,
        geometry: RadialGeometry,
        mode: RadialMode,
        animateEntrance: Bool = true
    ) {
        self.presentationID = presentationID
        self.items = items
        self.highlighted = highlighted
        self.title = title
        self.emptyMessage = emptyMessage
        self.emptyDetail = emptyDetail
        self.geometry = geometry
        self.mode = mode
        self.animateEntrance = animateEntrance
        self._scale = SwipState(wrappedValue: animateEntrance ? 0.85 : 1.0)
        self._opacity = SwipState(wrappedValue: animateEntrance ? 0.0 : 1.0)
    }

    public var body: some View {
        let wheelDiameter = geometry.outerRadius * 2 + 24
        let indexed = items.indices.map { IndexedRadialItem(index: $0, item: items[$0]) }

        ZStack {
            // Backdrop blur disc
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: wheelDiameter, height: wheelDiameter)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

            if items.isEmpty {
                VStack(spacing: 6) {
                    Text(emptyMessage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(emptyDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: geometry.innerRadius * 2 - 16)
                .multilineTextAlignment(.center)
            } else {
                // Petals
                ForEach(indexed) { entry in
                    RadialPetalView(
                        item: entry.item,
                        index: entry.index,
                        isHighlighted: highlighted == entry.index,
                        geometry: geometry,
                        totalCount: items.count,
                        wheelDiameter: wheelDiameter
                    )
                }

                // Center Disc
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    .frame(width: geometry.innerRadius * 2 - geometry.gap, height: geometry.innerRadius * 2 - geometry.gap)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
                    .overlay(
                        VStack(spacing: 3) {
                            Text(mode.title)
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Theme.accent)
                                .tracking(1.5)

                            Text(title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 8)

                            if let highlighted = highlighted, highlighted < items.count {
                                Text(items[highlighted].detail)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("Drop on petal")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
            }
        }
        .frame(width: wheelDiameter, height: wheelDiameter)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            guard animateEntrance else { return }
            if reduceMotion {
                scale = 1
                opacity = 1
            } else {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
    }
}

public final class RadialView: NSView {
    public var centerPoint: NSPoint = .zero
    public var discRadius: CGFloat = 175
    public var interactive = false
    public var mode: RadialMode = .convert
    public var items: [RadialItem] = [] { didSet { refresh() } }
    public var emptyMessage: String = "" { didSet { refresh() } }
    public var subtitle: String = "" { didSet { refresh() } }

    public var onSelect: ((RadialItem) -> Void)?
    public var onCancel: (() -> Void)?
    public var onDragEntered: ((NSDraggingInfo) -> Void)?
    public var onDragSessionEnded: (() -> Void)?

    private var highlighted: Int? {
        didSet {
            if oldValue != highlighted {
                if highlighted != nil {
                    SoundManager.shared.playHighlight()
                    SoundManager.shared.triggerHaptic()
                }
                refresh()
            }
        }
    }

    private var presentationID = UUID()
    private var trackingArea: NSTrackingArea?
    private let host = NSHostingView(rootView: AnyView(EmptyView()))

    public var geometry: RadialGeometry {
        RadialGeometry(innerRadius: 66, outerRadius: 155, gap: 4, count: items.count)
    }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("com.apple.finder.node")])
        wantsLayer = true
        host.sizingOptions = []
        addSubview(host)
    }

    required init?(coder: NSCoder) { fatalError("Not supported") }

    public override var acceptsFirstResponder: Bool { true }
    public override var isFlipped: Bool { false }

    public override func layout() {
        super.layout()
        host.frame = NSRect(
            x: centerPoint.x - discRadius,
            y: centerPoint.y - discRadius,
            width: discRadius * 2,
            height: discRadius * 2
        )
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    public func animatePresentation() {
        presentationID = UUID()
        refresh()
    }

    private func refresh() {
        let currentTitle: String
        if let highlighted = highlighted, highlighted < items.count {
            currentTitle = items[highlighted].label
        } else {
            currentTitle = items.count == 1 ? items[0].label : mode.title
        }

        host.rootView = AnyView(
            RadialWheelView(
                presentationID: presentationID,
                items: items,
                highlighted: highlighted,
                title: currentTitle,
                emptyMessage: emptyMessage,
                emptyDetail: subtitle,
                geometry: geometry,
                mode: mode
            )
        )
    }

    public func index(at point: NSPoint) -> Int? {
        geometry.index(at: CGPoint(x: point.x - centerPoint.x, y: point.y - centerPoint.y))
    }

    public func updateHighlight(forWindowPoint point: NSPoint) {
        layoutSubtreeIfNeeded()
        let viewPoint = convert(point, from: nil)
        highlighted = index(at: viewPoint)
    }

    public func clearHighlight() {
        highlighted = nil
    }

    public func highlight(_ idx: Int) {
        highlighted = items.indices.contains(idx) ? idx : nil
    }

    // MARK: - Drag Destination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?(sender)
        updateHighlight(forWindowPoint: sender.draggingLocation)
        return highlighted == nil ? [] : .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHighlight(forWindowPoint: sender.draggingLocation)
        return highlighted == nil ? [] : .copy
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return highlighted != nil
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        highlighted = nil
        if let window = window, sender != nil, NSEvent.pressedMouseButtons & 1 == 1 {
            if window.frame.insetBy(dx: 1, dy: 1).contains(NSEvent.mouseLocation) {
                onDragSessionEnded?()
            }
        }
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        highlighted = nil
        onDragSessionEnded?()
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        updateHighlight(forWindowPoint: sender.draggingLocation)
        guard let highlighted = highlighted, highlighted < items.count else {
            onCancel?()
            return false
        }
        let item = items[highlighted]
        SoundManager.shared.playDrop()
        DispatchQueue.main.async { [weak self] in
            self?.onSelect?(item)
        }
        return true
    }

    // MARK: - Interactive Mouse/Keyboard Events
    public override func mouseMoved(with event: NSEvent) {
        guard interactive else { return }
        updateHighlight(forWindowPoint: event.locationInWindow)
    }

    public override func mouseDown(with event: NSEvent) {
        guard interactive else { return }
        updateHighlight(forWindowPoint: event.locationInWindow)
        if let highlighted = highlighted, highlighted < items.count {
            onSelect?(items[highlighted])
        } else {
            onCancel?()
        }
    }

    public override func keyDown(with event: NSEvent) {
        guard interactive else { return }
        switch event.keyCode {
        case 53: // Escape
            onCancel?()
        case 36, 76: // Return / Enter
            if let highlighted = highlighted, highlighted < items.count {
                onSelect?(items[highlighted])
            }
        case 123, 126: // Left, Up
            step(-1)
        case 124, 125: // Right, Down
            step(1)
        default:
            super.keyDown(with: event)
        }
    }

    private func step(_ delta: Int) {
        guard !items.isEmpty else { return }
        let current = highlighted ?? -1
        var next = (current + delta) % items.count
        if next < 0 { next += items.count }
        highlighted = next
    }
}
