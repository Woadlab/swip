import AppKit
import SwiftUI

public final class FloatingShelfController: ObservableObject {
    public static let shared = FloatingShelfController()

    @Published public private(set) var items: [URL] = []
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
    }

    @MainActor
    public func hide() {
        window?.orderOut(nil)
    }

    @MainActor
    public func toggle() {
        if let window = window, window.isVisible {
            hide()
        } else {
            show()
        }
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

        let view = FloatingShelfView()
        panel.contentView = NSHostingView(rootView: view)
        self.window = panel
    }
}
