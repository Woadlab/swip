import AppKit
import Combine
import SwiftUI

// MARK: - Actions

/// Everything the menu bar panel can trigger. Owned by the AppDelegate.
struct MenuBarActions {
    var openStudio: () -> Void
    var openSettings: () -> Void
    var convert: () -> Void
    var tools: () -> Void
    var fileActions: () -> Void
    var toggleShelf: () -> Void
    var showLogs: () -> Void
    var quit: () -> Void
}

@MainActor
final class MenuBarPanelModel: ObservableObject {
    /// Drives the entrance choreography; flipped after the window is on screen.
    @Published var presented = false
    /// Reports the card's laid-out height so the window can hug it.
    var onCardHeight: ((CGFloat) -> Void)?
}

private struct CardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Panel window

private final class MenuBarPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A borderless, non-activating panel anchored under the status item. Replaces
/// the stock NSMenu so the menu can carry live job state, hover tracking and
// quiet motion.
@MainActor
final class MenuBarPanelController {
    static let cardWidth: CGFloat = 320
    static let shadowInset: CGFloat = 24
    private var cardHeight: CGFloat = 440

    private weak var button: NSStatusBarButton?
    private let actions: MenuBarActions
    private let model = MenuBarPanelModel()
    private var panel: MenuBarPanelWindow?
    private var monitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?
    private var closeGeneration = 0

    var isShown: Bool { panel?.isVisible == true && model.presented }

    init(button: NSStatusBarButton, actions: MenuBarActions) {
        self.button = button
        self.actions = actions
    }

    func toggle() {
        isShown ? close() : show()
    }

    func show() {
        guard let button, let buttonWindow = button.window else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        closeGeneration += 1

        let inset = Self.shadowInset
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        let width = Self.cardWidth + inset * 2
        let height = cardHeight + inset * 2
        var cardX = buttonRect.midX - Self.cardWidth / 2
        cardX = min(max(cardX, visible.minX + 8), visible.maxX - Self.cardWidth - 8)
        let cardTop = min(buttonRect.minY - 6, visible.maxY - 2)
        panel.setFrame(NSRect(x: cardX - inset, y: cardTop + inset - height, width: width, height: height), display: false)

        model.presented = false
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)
        installMonitors()

        DispatchQueue.main.async { [model] in
            withAnimation(Motion.entrance) { model.presented = true }
        }
    }

    func close(then action: (() -> Void)? = nil) {
        removeMonitors()
        button?.highlight(false)
        guard let panel, panel.isVisible else {
            action?()
            return
        }
        closeGeneration += 1
        let generation = closeGeneration
        withAnimation(.easeOut(duration: 0.14)) { model.presented = false }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.closeGeneration == generation else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
        // Run the action right away; the fade finishes behind it.
        action?()
    }

    /// Grows immediately; shrinks after the layout animation settles so content
    /// animating out is never clipped by the window edge.
    private func updateCardHeight(_ height: CGFloat) {
        guard height > 1, abs(height - cardHeight) > 0.5 else { return }
        let growing = height > cardHeight
        cardHeight = height
        if growing {
            applyCardHeight()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, self.cardHeight == height else { return }
                self.applyCardHeight()
            }
        }
    }

    private func applyCardHeight() {
        guard let panel else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size.height = cardHeight + Self.shadowInset * 2
        frame.origin.y = top - frame.height
        panel.setFrame(frame, display: true)
    }

    private func makePanel() -> MenuBarPanelWindow {
        let panel = MenuBarPanelWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // drawn in SwiftUI so it follows the card's live height
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        model.onCardHeight = { [weak self] height in self?.updateCardHeight(height) }
        let wrapped = MenuBarPanelView(model: model, actions: wrap(actions))
        let host = NSHostingView(rootView: wrapped)
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }

    /// Every action dismisses the panel first, like a real menu.
    private func wrap(_ a: MenuBarActions) -> MenuBarActions {
        func dismissing(_ f: @escaping () -> Void) -> () -> Void {
            { [weak self] in self?.close(then: f) ?? f() }
        }
        return MenuBarActions(
            openStudio: dismissing(a.openStudio),
            openSettings: dismissing(a.openSettings),
            convert: dismissing(a.convert),
            tools: dismissing(a.tools),
            fileActions: dismissing(a.fileActions),
            toggleShelf: dismissing(a.toggleShelf),
            showLogs: dismissing(a.showLogs),
            quit: a.quit
        )
    }

    private func installMonitors() {
        removeMonitors()
        // Clicks in other apps (or on the desktop) dismiss the panel.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) {
            monitors.append(global)
        }
        // Escape closes; clicks in our own windows other than the panel close too.
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .leftMouseUp], handler: { [weak self] event in
            let type = event.type
            let isEscape = type == .keyDown && event.keyCode == 53
            let clickedWindow = event.window.map(ObjectIdentifier.init)
            let location = event.locationInWindow
            let swallow = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                if isEscape {
                    self.close()
                    return true
                }
                let panelID = self.panel.map(ObjectIdentifier.init)
                let buttonWindowID = self.button?.window.map(ObjectIdentifier.init)
                switch type {
                case .leftMouseUp:
                    // NSStatusBarButton drops its highlight on mouse-up; restore it.
                    if clickedWindow == buttonWindowID, self.panel?.isVisible == true {
                        DispatchQueue.main.async { self.button?.highlight(self.isShown) }
                    }
                case .leftMouseDown, .rightMouseDown:
                    if clickedWindow == panelID {
                        // The window is larger than the card (room for the shadow);
                        // a click in that transparent margin counts as "outside".
                        if !self.cardRectInWindow.contains(location) {
                            self.close()
                            return true
                        }
                    } else if clickedWindow != buttonWindowID {
                        self.close()
                    }
                default:
                    break
                }
                return false
            }
            return swallow ? nil : event
        }) {
            monitors.append(local)
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private var cardRectInWindow: NSRect {
        guard let bounds = panel?.contentView?.bounds else { return .zero }
        return bounds.insetBy(dx: Self.shadowInset, dy: Self.shadowInset)
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
    }
}

// MARK: - Motion tokens

/// One easing curve, three durations.
enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.easeOut(duration: 0.12)
    static let entrance = Animation.easeOut(duration: 0.2)
    static let layout = Animation.easeOut(duration: 0.24)
}

// MARK: - Root view

struct MenuBarPanelView: View {
    @ObservedObject var model: MenuBarPanelModel
    let actions: MenuBarActions

    @ObservedObject private var jobs = JobRunner.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var shelf = FloatingShelfController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var hoverSpace
    @SwipState private var hoveredRow: String?

    private var recentJobs: [Job] {
        Array(jobs.jobs.filter { $0.status.isFinished }.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            card
                .background(GeometryReader { geo in
                    Color.clear.preference(key: CardHeightKey.self, value: geo.size.height)
                })
                .onPreferenceChange(CardHeightKey.self) { height in
                    MainActor.assumeIsolated { model.onCardHeight?(height) }
                }
                .offset(y: reduceMotion ? 0 : (model.presented ? 0 : -4))
                .opacity(model.presented ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(MenuBarPanelController.shadowInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(Theme.accent)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuHeader(activeJob: jobs.activeJob, presented: model.presented)
                .reveal(0, model.presented)

            if let job = jobs.activeJob {
                ActiveJobCard(job: job)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -4)),
                        removal: .opacity
                    ))
            }

            HStack(spacing: 8) {
                ModeTile(title: "Convert", symbol: "arrow.triangle.2.circlepath", key: "⇧", hue: Theme.accent, action: actions.convert)
                ModeTile(title: "Tools", symbol: "wand.and.stars", key: "⌘", hue: Color(red: 0.16, green: 0.58, blue: 0.92), action: actions.tools)
                ModeTile(title: "Actions", symbol: "square.on.square", key: "⌃", hue: Color(red: 0.95, green: 0.50, blue: 0.20), action: actions.fileActions)
            }
            .padding(.horizontal, 10)
            .reveal(1, model.presented)

            Text("Hold the key while dragging a file, or click to pick one")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .reveal(1, model.presented)

            MenuDivider()

            VStack(spacing: 0) {
                MenuRow(id: "studio", title: "Open Swip Studio", symbol: "macwindow", shortcut: "⌘O",
                        hovered: $hoveredRow, space: hoverSpace, action: actions.openStudio)
                    .keyboardShortcut("o", modifiers: .command)
                MenuRow(id: "shelf", title: "Floating Shelf", symbol: "tray.full", shortcut: nil,
                        hovered: $hoveredRow, space: hoverSpace, action: actions.toggleShelf) {
                    StatusPill(on: shelf.isVisible, count: shelf.items.count)
                }
                MenuRow(id: "settings", title: "Settings…", symbol: "gearshape", shortcut: "⌘,",
                        hovered: $hoveredRow, space: hoverSpace, action: actions.openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                LoginRow(isOn: $settings.launchAtLogin, hovered: $hoveredRow, space: hoverSpace)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .reveal(2, model.presented)

            if !recentJobs.isEmpty {
                MenuDivider()
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Recent")
                    ForEach(recentJobs) { job in
                        RecentRow(job: job, hovered: $hoveredRow, space: hoverSpace)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .reveal(3, model.presented)
                .transition(.opacity)
            }

            MenuDivider()

            MenuFooter(showLogs: actions.showLogs, quit: actions.quit)
                .reveal(4, model.presented)
        }
        .frame(width: MenuBarPanelController.cardWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background { PanelBackground() }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 16, y: 8)
        .animation(Motion.layout, value: jobs.activeJob?.id)
        .animation(Motion.layout, value: recentJobs.map(\.id))
        .onHover { if !$0 { withAnimation(Motion.hover) { hoveredRow = nil } } }
    }
}

// MARK: - Background

private struct PanelBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VisualEffectBackdrop(material: .popover)
            // Mostly-opaque base: keeps text and tiles crisp on busy or tinted wallpapers.
            Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.78 : 0.86)
        }
    }
}

struct VisualEffectBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Header

private struct MenuHeader: View {
    let activeJob: Job?
    let presented: Bool

    var body: some View {
        HStack(spacing: 11) {
            SwipMark(spinning: activeJob != nil, presented: presented)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Swip")
                    .font(.system(size: 14, weight: .semibold))
                Group {
                    if let job = activeJob {
                        JobStatusText(job: job)
                    } else {
                        Text("Ready")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
            }

            Spacer(minLength: 0)

            LiveBadge(busy: activeJob != nil, running: presented)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

private struct JobStatusText: View {
    @ObservedObject var job: Job
    var body: some View {
        Text(job.progress > 0 ? "Working · \(Int(job.progress * 100))%" : "Working…")
            .monospacedDigit()
    }
}

/// The brand mark rebuilt in SwiftUI so it can move: it sweeps in when the
/// panel opens and keeps turning while a job runs.
struct SwipMark: View {
    var spinning: Bool
    var presented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !spinning || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let spin = spinning && !reduceMotion ? Angle.degrees((t * 220).truncatingRemainder(dividingBy: 360)) : .zero
            GeometryReader { geo in
                let s = geo.size.width
                ZStack {
                    RoundedRectangle(cornerRadius: s * 0.27, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.17, green: 0.18, blue: 0.29), Color(red: 0.06, green: 0.065, blue: 0.11)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    RoundedRectangle(cornerRadius: s * 0.27, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)

                    // Same petals as the app icon (BrandArtwork.petal), drawn live so
                    // the wheel can turn and follow the user's accent color.
                    Canvas { ctx, size in
                        let spec = BrandArtwork.WheelSpec.tile
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let slot = CGFloat.pi * 2 / 8
                        for i in 0..<8 {
                            // y-down canvas: negative angles run counter-clockwise, so
                            // index 1 lands at the north-east like the app icon.
                            let path = Path(BrandArtwork.petal(center: c, angle: -CGFloat(i) * slot, spec: spec,
                                                               size: size.width, popped: i == 1))
                            ctx.fill(path, with: .color(i == 1 ? Theme.accent : Color(red: 0.84, green: 0.87, blue: 0.95).opacity(0.22)))
                        }
                    }
                    .rotationEffect(spin)

                    Circle()
                        .fill(.white)
                        .frame(width: s * BrandArtwork.WheelSpec.tile.dot * 2, height: s * BrandArtwork.WheelSpec.tile.dot * 2)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: spinning)
    }
}

private struct LiveBadge: View {
    let busy: Bool
    let running: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(busy ? Theme.accent : Color.green.opacity(0.85))
                .frame(width: 6, height: 6)
            Text(busy ? "Working" : "On")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .help(busy ? "A conversion is running" : "Swip is watching for modifier-drags")
    }
}

// MARK: - Active job

private struct ActiveJobCard: View {
    @ObservedObject var job: Job
    @SwipState private var hoveringCancel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: job.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(job.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(job.detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Button {
                    JobRunner.shared.cancel(job: job)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(hoveringCancel ? .primary : .tertiary)
                }
                .buttonStyle(.plain)
                .onHover { hoveringCancel = $0 }
                .help("Cancel")
            }
            JobProgressBar(value: job.progress)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
    }
}

private struct JobProgressBar: View {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fill = max(6, w * min(max(value, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: fill)
                    .animation(Motion.layout, value: value)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Mode tiles

private struct ModeTile: View {
    let title: String
    let symbol: String
    let key: String
    let hue: Color
    let action: () -> Void

    @SwipState private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    // Solid, saturated disc with a white glyph: reads at full
                    // contrast in both appearances and over any backdrop.
                    Circle()
                        .fill(hue)
                        .overlay {
                            Image(systemName: symbol)
                                .symbolRenderingMode(.monochrome)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                        .frame(width: 38, height: 38)
                    Keycap(key)
                        .offset(x: 9, y: -4)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDark ? Color.white.opacity(hovering ? 0.12 : 0.07) : Color.white.opacity(hovering ? 1 : 0.8))
                    .shadow(color: .black.opacity(isDark ? 0 : 0.04), radius: 1, y: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(hovering ? 0.16 : (isDark ? 0.10 : 0.08)), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in withAnimation(Motion.hover) { hovering = inside } }
        .help("\(title) — hold \(key) while dragging, or click to pick files")
    }
}

private struct Keycap: View {
    let glyph: String
    init(_ glyph: String) { self.glyph = glyph }

    var body: some View {
        Text(glyph)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(Color(nsColor: .labelColor).opacity(0.75))
            .frame(minWidth: 16, minHeight: 15)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
            }
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

private struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Rows

/// A menu row whose hover highlight is one shared shape that glides between
/// rows (matchedGeometryEffect), instead of each row flashing independently.
private struct MenuRow<Trailing: View>: View {
    let id: String
    let title: String
    let symbol: String
    let shortcut: String?
    @Binding var hovered: String?
    let space: Namespace.ID
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(id: String, title: String, symbol: String, shortcut: String?, hovered: Binding<String?>, space: Namespace.ID,
         action: @escaping () -> Void, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self._hovered = hovered
        self.space = space
        self.action = action
        self.trailing = trailing
    }

    var body: some View {
        let isHovered = hovered == id
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isHovered ? Theme.accent : .secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                trailing()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
            .background { HoverHighlight(active: isHovered, space: space) }
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in
            if inside && hovered != id { withAnimation(Motion.hover) { hovered = id } }
        }
    }
}

extension MenuRow where Trailing == EmptyView {
    init(id: String, title: String, symbol: String, shortcut: String?, hovered: Binding<String?>, space: Namespace.ID,
         action: @escaping () -> Void) {
        self.init(id: id, title: title, symbol: symbol, shortcut: shortcut, hovered: hovered, space: space,
                  action: action, trailing: { EmptyView() })
    }
}

private struct HoverHighlight: View {
    let active: Bool
    let space: Namespace.ID

    var body: some View {
        if active {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent.opacity(0.18), lineWidth: 0.5))
                .matchedGeometryEffect(id: "menu-hover", in: space)
        }
    }
}

private struct LoginRow: View {
    @Binding var isOn: Bool
    @Binding var hovered: String?
    let space: Namespace.ID

    var body: some View {
        let isHovered = hovered == "login"
        HStack(spacing: 10) {
            Image(systemName: "power.circle")
                .font(.system(size: 13))
                .foregroundStyle(isHovered ? Theme.accent : .secondary)
                .frame(width: 18)
            Text("Open at Login")
                .font(.system(size: 13))
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(!InstanceGuard.isInstalledCopy)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .contentShape(Rectangle())
        .background { HoverHighlight(active: isHovered, space: space) }
        .onTapGesture { if InstanceGuard.isInstalledCopy { isOn.toggle() } }
        .onHover { inside in
            if inside && hovered != "login" { withAnimation(Motion.hover) { hovered = "login" } }
        }
        .help(InstanceGuard.isInstalledCopy ? "Start Swip automatically when you log in" : "Only the copy in /Applications can open at login")
    }
}

private struct StatusPill: View {
    let on: Bool
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Circle()
                .fill(on ? Color.green : Color.primary.opacity(0.25))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .foregroundStyle(.secondary)
        .animation(Motion.hover, value: on)
    }
}

private struct RecentRow: View {
    @ObservedObject var job: Job
    @Binding var hovered: String?
    let space: Namespace.ID

    private var rowID: String { "recent-\(job.id)" }

    var body: some View {
        let isHovered = hovered == rowID
        Button {
            if let first = job.outputs.first {
                NSWorkspace.shared.activateFileViewerSelecting([first])
            }
        } label: {
            HStack(spacing: 9) {
                statusIcon
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(job.outputs.first?.lastPathComponent ?? job.detail)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if isHovered && !job.outputs.isEmpty {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background { HoverHighlight(active: isHovered, space: space) }
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in
            if inside && hovered != rowID { withAnimation(Motion.hover) { hovered = rowID } }
        }
        .help(job.outputs.isEmpty ? job.title : "Show in Finder")
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        default:
            Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        }
    }

    private var subtitle: String {
        let when = job.date.formatted(.relative(presentation: .named))
        switch job.status {
        case .failed(let reason): return "Failed · \(reason)"
        case .cancelled: return "Cancelled · \(when)"
        default: return "\(job.title) · \(when)"
        }
    }
}

// MARK: - Footer & bits

private struct MenuFooter: View {
    let showLogs: () -> Void
    let quit: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 10))
            Text("Swip \(version) · Offline")
                .font(.system(size: 10.5))
            Spacer()
            FooterIconButton(symbol: "doc.text.magnifyingglass", help: "Show Diagnostic Logs", action: showLogs)
            FooterIconButton(symbol: "power", help: "Quit Swip (⌘Q)", action: quit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
    }
}

private struct FooterIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @SwipState private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? .primary : .secondary)
                .frame(width: 26, height: 24)
                .background(Color.primary.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in withAnimation(Motion.hover) { hovering = inside } }
        .help(help)
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 3)
    }
}

private struct MenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 12)
    }
}

// MARK: - Staggered reveal

private struct Reveal: ViewModifier {
    let index: Int
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 4)
            .animation(Motion.entrance.delay(shown ? Double(index) * 0.025 : 0), value: shown)
    }
}

private extension View {
    func reveal(_ index: Int, _ shown: Bool) -> some View {
        modifier(Reveal(index: index, shown: shown))
    }
}
