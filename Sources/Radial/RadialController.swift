import AppKit

public final class RadialController: DragMonitorDelegate {
    private var panel: RadialPanel?
    private var urls: [URL] = []
    private var formats: [FileFormat] = []
    private var mode: RadialMode = .convert
    private var visible = false
    private var pickerMode = false
    private var outsideClickMonitor: Any?

    public weak var dragMonitor: DragMonitor?

    public init() {}

    public func dragMonitor(_ monitor: DragMonitor, didBeginModifiedDrag urls: [URL], at point: NSPoint, mode: RadialMode) {
        dragMonitor = monitor
        pickerMode = false
        self.mode = mode
        present(urls: urls, at: point, mode: mode)
    }

    public func dragMonitor(_ monitor: DragMonitor, didChangeMode mode: RadialMode, at point: NSPoint) {
        guard !pickerMode else { return }
        if self.mode != mode {
            self.mode = mode
            reloadItems()
        }
        if !visible {
            present(urls: urls, at: point, mode: mode)
            return
        }
        if let panel = panel {
            panel.radialView.updateHighlight(forWindowPoint: panel.convertPoint(fromScreen: point))
        }
    }

    public func dragMonitor(_ monitor: DragMonitor, didUpdateDraggedURLs urls: [URL]) {
        adopt(urls)
    }

    public func dragMonitorDidEndDrag(_ monitor: DragMonitor) {
        guard !pickerMode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, !self.pickerMode else { return }
            self.hide()
        }
    }

    public func presentPicker(for urls: [URL], mode: RadialMode = .convert) {
        self.mode = mode
        pickerMode = true
        let point = NSEvent.mouseLocation
        present(urls: urls, at: point, mode: mode)
        panel?.radialView.interactive = true
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(panel?.radialView)
        NSApp.activate(ignoringOtherApps: true)
        installOutsideClickMonitor()
    }

    private func present(urls: [URL], at point: NSPoint, mode: RadialMode) {
        self.urls = urls
        self.mode = mode
        formats = urls.compactMap(FileFormat.detect)

        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let panel = self.panel ?? RadialPanel(screen: screen)
        panel.setFrame(screen.frame, display: false)
        self.panel = panel

        let view = panel.radialView
        view.frame = NSRect(origin: .zero, size: screen.frame.size)
        view.interactive = pickerMode
        view.mode = mode
        let clamped = clampedCenter(point, in: screen.frame, radius: view.discRadius + 40)
        view.centerPoint = panel.convertPoint(fromScreen: clamped)
        view.updateHostFrame()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.onSelect = { [weak self] item in self?.select(item) }
        view.onCancel = { [weak self] in self?.hide() }
        view.onDragEntered = { [weak self] info in self?.adoptDraggedFiles(from: info) }
        view.onDragSessionEnded = { [weak self] in self?.dragSessionEnded() }
        view.clearHighlight()
        reloadItems()
        view.animatePresentation()

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
        visible = true
    }

    private func clampedCenter(_ point: NSPoint, in frame: NSRect, radius: CGFloat) -> NSPoint {
        NSPoint(
            x: min(max(point.x, frame.minX + radius), frame.maxX - radius),
            y: min(max(point.y, frame.minY + radius), frame.maxY - radius)
        )
    }

    private func adoptDraggedFiles(from info: NSDraggingInfo) {
        guard !pickerMode else { return }
        let dragged = DragMonitor.fileURLs(on: info.draggingPasteboard)
        adopt(dragged)
    }

    private func adopt(_ dragged: [URL]) {
        guard !pickerMode, visible, !dragged.isEmpty, dragged != urls else { return }
        urls = dragged
        formats = dragged.compactMap(FileFormat.detect)
        reloadItems()
    }

    private func dragSessionEnded() {
        guard !pickerMode, visible else { return }
        hide()
        dragMonitor?.markHandled()
    }

    private func reloadItems() {
        guard let view = panel?.radialView else { return }
        view.mode = mode
        let count = urls.count
        if count == 0 {
            view.items = []
            view.subtitle = "Move files over the wheel"
            view.emptyMessage = mode == .tools ? "Drop here for tools" : (mode == .actions ? "Drop here for actions" : "Drop here to convert")
            return
        }

        view.subtitle = count == 1 ? urls[0].lastPathComponent : "\(count) files"

        switch mode {
        case .actions:
            view.items = FileAction.allCases.map(RadialItem.init(fileAction:))
            view.emptyMessage = "No file actions"

        case .tools:
            if formats.count != urls.count {
                view.items = []
                view.emptyMessage = "Selection contains unsupported files"
            } else {
                let tools = ToolID.available(for: formats)
                view.items = tools.map(RadialItem.init(tool:))
                view.emptyMessage = "No tools available for this file type"
            }

        case .convert:
            if formats.count != urls.count {
                view.items = []
                view.emptyMessage = "Selection contains unsupported files"
            } else {
                let targets = ConversionMatrix.targets(for: formats)
                view.items = targets.map(RadialItem.init(format:))
                view.emptyMessage = count > 1 ? "No shared format for selection" : "No conversions available"
            }
        }
    }

    private func select(_ item: RadialItem) {
        let selectedURLs = urls
        DiagnosticLog.log("Radial selected \(item.detail) for \(selectedURLs.count) file(s)")
        hide()
        dragMonitor?.markHandled()

        Task { @MainActor in
            switch item.action {
            case .fileAction(let action):
                action.run(selectedURLs)

            case .convert(let target):
                JobRunner.shared.convert(selectedURLs, to: target)

            case .tool(let tool):
                ToolWindowManager.shared.open(tool, files: selectedURLs)
            }
        }
    }

    public func hide() {
        visible = false
        pickerMode = false
        panel?.radialView.clearHighlight()
        panel?.radialView.interactive = false
        panel?.orderOut(nil)
        if let outsideClickMonitor = outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func installOutsideClickMonitor() {
        if let outsideClickMonitor = outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }
}
