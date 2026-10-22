import AppKit

public protocol DragMonitorDelegate: AnyObject {
    func dragMonitor(_ monitor: DragMonitor, didBeginModifiedDrag urls: [URL], at point: NSPoint, mode: RadialMode)
    func dragMonitor(_ monitor: DragMonitor, didChangeMode mode: RadialMode, at point: NSPoint)
    func dragMonitor(_ monitor: DragMonitor, didUpdateDraggedURLs urls: [URL])
    func dragMonitorDidEndDrag(_ monitor: DragMonitor)
}

public enum RadialMode: Equatable {
    case convert
    case tools
    case actions

    public var title: String {
        switch self {
        case .convert: return "CONVERT"
        case .tools: return "TOOLS"
        case .actions: return "ACTIONS"
        }
    }
}

public final class DragMonitor {
    public weak var delegate: DragMonitorDelegate?

    private var monitors: [Any] = []
    private var pollTimer: Timer?
    private var activity: NSObjectProtocol?
    private var pressChangeCount = 0
    private var lastReadChange = 0
    private var activeURLs: [URL] = []
    private var dragInFlight = false
    private var presenting = false
    private var handled = false
    private var mouseDown = false
    private var pressOrigin = NSPoint.zero
    private var pressTime = Date.distantPast
    private var pressInFinder = false
    private var pressExcluded = false
    private var currentMode: RadialMode?

    private static let idleInterval = 1.0 / 30.0
    private static let dragInterval = 1.0 / 60.0
    private static let fallbackDragDistance: CGFloat = 20
    private static let fallbackDelay: TimeInterval = 0.25

    public init() {}

    public func start() {
        stop()
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] _ in
            self?.beginPressIfNeeded()
            self?.poll()
        }
        let down = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.beginPressIfNeeded()
            self?.poll()
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] _ in
            self?.finishPress()
        }
        let flags = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] _ in
            self?.poll()
        }
        monitors = [dragged, down, up, flags].compactMap { $0 }
        schedulePoll(interval: Self.idleInterval)
        DiagnosticLog.log("DragMonitor started with \(monitors.count) event monitors")
    }

    public func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
        endActivity()
    }

    public func markHandled() {
        handled = true
        presenting = false
        activeURLs = []
        currentMode = nil
    }

    private func schedulePoll(interval: TimeInterval) {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.poll() }
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private var buttonPressed: Bool { NSEvent.pressedMouseButtons != 0 }

    private var activeModifierMode: RadialMode? {
        let flags = NSEvent.modifierFlags
        // Tangerine keys:
        // Shift -> Convert
        // Command -> Tools
        // Control -> Actions
        if flags.contains(.control) {
            return .actions
        } else if flags.contains(.command) || (flags.contains(.shift) && flags.contains(.option)) {
            return .tools
        } else if flags.contains(.shift) {
            return .convert
        }
        return nil
    }

    private func beginPressIfNeeded() {
        guard !mouseDown else { return }
        mouseDown = true
        handled = false
        dragInFlight = false
        activeURLs = []
        currentMode = nil
        pressOrigin = NSEvent.mouseLocation
        pressTime = Date()
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        pressInFinder = sourceApp == "com.apple.finder"
        pressExcluded = sourceApp.map { AppSettings.shared.excludedApplications[$0] != nil } ?? false
        pressChangeCount = NSPasteboard(name: .drag).changeCount
        lastReadChange = -1
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Tracking Swip file drag"
        )
        schedulePoll(interval: Self.dragInterval)
    }

    private func poll() {
        guard buttonPressed else {
            if mouseDown { finishPress() }
            return
        }
        beginPressIfNeeded()
        guard !pressExcluded else { return }

        refreshDragPasteboard()

        let dist = hypot(NSEvent.mouseLocation.x - pressOrigin.x, NSEvent.mouseLocation.y - pressOrigin.y)
        if !dragInFlight, dist >= 5 {
            let pasteboard = NSPasteboard(name: .drag)
            let types = pasteboard.types ?? []
            let hasFiles = types.contains(.fileURL) || types.contains(where: {
                NSFilePromiseReceiver.readableDraggedTypes.contains($0.rawValue) ||
                $0.rawValue == "com.apple.finder.node"
            })
            if hasFiles || pasteboard.changeCount > pressChangeCount || activeModifierMode != nil {
                dragInFlight = true
            }
        }

        evaluateModifiers()
    }

    private func refreshDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
        let change = pasteboard.changeCount
        // Keep inspecting if changeCount incremented OR if we are dragging but haven't captured files yet
        if change != lastReadChange || activeURLs.isEmpty {
            lastReadChange = change
            let urls = Self.fileURLs(on: pasteboard)
            if !urls.isEmpty {
                activeURLs = urls
                dragInFlight = true
                if presenting {
                    delegate?.dragMonitor(self, didUpdateDraggedURLs: activeURLs)
                }
            } else {
                let types = pasteboard.types ?? []
                let hasFileTypes = types.contains(.fileURL) || types.contains(where: {
                    NSFilePromiseReceiver.readableDraggedTypes.contains($0.rawValue) ||
                    $0.rawValue == "com.apple.finder.node"
                })
                if hasFileTypes || change > pressChangeCount {
                    dragInFlight = true
                }
            }
        }
    }

    public static func fileURLs(on pasteboard: NSPasteboard) -> [URL] {
        var urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        if urls.isEmpty {
            urls = (pasteboard.pasteboardItems ?? []).compactMap { item in
                item.string(forType: .fileURL).flatMap { URL(string: $0) }
            }
        }
        return urls.compactMap { url -> URL? in
            let resolved = (url as NSURL).filePathURL ?? url
            guard resolved.isFileURL else { return nil }
            return resolved.standardizedFileURL
        }
    }

    private func evaluateModifiers() {
        guard mouseDown, dragInFlight, !handled else { return }
        let point = NSEvent.mouseLocation

        if let mode = activeModifierMode {
            if !presenting {
                presenting = true
                currentMode = mode
                SoundManager.shared.playHighlight()
                delegate?.dragMonitor(self, didBeginModifiedDrag: activeURLs, at: point, mode: mode)
            } else if currentMode != mode {
                currentMode = mode
                SoundManager.shared.playHighlight()
                delegate?.dragMonitor(self, didChangeMode: mode, at: point)
            }
        } else if presenting {
            // Releasing the modifier while dragging dismisses the wheel cleanly
            presenting = false
            currentMode = nil
            delegate?.dragMonitorDidEndDrag(self)
        }
    }

    private func finishPress() {
        guard mouseDown else { return }
        mouseDown = false
        dragInFlight = false
        handled = false
        activeURLs = []
        currentMode = nil
        endActivity()
        schedulePoll(interval: Self.idleInterval)
        if presenting {
            presenting = false
            delegate?.dragMonitorDidEndDrag(self)
        }
    }

    private func endActivity() {
        if let activity = activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
