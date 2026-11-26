import AppKit
import SwiftUI

public final class FloatingShelfController: ObservableObject {
    public static let shared = FloatingShelfController()

    @Published public private(set) var items: [URL] = []
    @Published public private(set) var isVisible = false
    private var window: NSPanel?

    private init() {}

    @MainActor
    public func add(urls: [URL]) {
        for url in urls where !items.contains(url) {
            items.append(url)
        }
        show()
    }

    @MainActor
    public func remove(url: URL) {
        items.removeAll { $0 == url }
        if items.isEmpty {
            hide()
        }
    }

    @MainActor
    public func clear() {
        items.removeAll()
        hide()
    }

    @MainActor
    public func show() {
        if window == nil {
            createWindow()
        }
        window?.orderFrontRegardless()
        isVisible = window != nil
    }

    @MainActor
    public func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    @MainActor
    public func toggle() {
        if let window = window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    @objc private func shelfWillClose(_ note: Notification) {
        isVisible = false
    }

    @MainActor
    private func createWindow() {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 320
        let height: CGFloat = 460
        let frame = NSRect(
            x: screen.visibleFrame.maxX - width - 20,
            y: screen.visibleFrame.midY - height / 2,
            width: width,
            height: height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(self, selector: #selector(shelfWillClose), name: NSWindow.willCloseNotification, object: panel)

        let view = FloatingShelfView()
        panel.contentView = NSHostingView(rootView: view)
        self.window = panel
    }
}
