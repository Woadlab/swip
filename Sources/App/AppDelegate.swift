import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let dragMonitor = DragMonitor()
    private let radial = RadialController()
    private var studioWindow: NSWindow?
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.start()
        NSApp.setActivationPolicy(.accessory)
        AppSettings.shared.applyAppearance()
        NSApp.applicationIconImage = BrandArtwork.image(size: 256)

        installStatusItem()

        dragMonitor.delegate = radial
        dragMonitor.start()

        // Show studio window on initial launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            openStudio()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        radial.presentPicker(for: urls)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = BrandArtwork.image(size: 18, template: true)
            button.imagePosition = .imageOnly
            button.toolTip = "Swip: Hold Shift while dragging a file to convert"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Swip Studio", action: #selector(openStudio), keyEquivalent: "o").target = self
        menu.addItem(withTitle: "Convert Files…", action: #selector(convertFiles), keyEquivalent: "k").target = self
        menu.addItem(withTitle: "File Tools…", action: #selector(openTool), keyEquivalent: "t").target = self
        menu.addItem(withTitle: "File Actions…", action: #selector(fileActions), keyEquivalent: "a").target = self
        menu.addItem(withTitle: "Floating Shelf", action: #selector(toggleFloatingShelf), keyEquivalent: "f").target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Show Diagnostic Logs", action: #selector(showLogs), keyEquivalent: "l").target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Swip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let icons = [
            "Open Swip Studio": "sparkles",
            "Convert Files…": "arrow.triangle.2.circlepath",
            "File Tools…": "wrench.and.screwdriver",
            "File Actions…": "doc.on.doc",
            "Floating Shelf": "pin.fill",
            "Settings…": "gearshape",
            "Show Diagnostic Logs": "doc.text.magnifyingglass",
            "Quit Swip": "power"
        ]
        for item in menu.items {
            if let symbol = icons[item.title] {
                item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: item.title)
            }
        }

        item.menu = menu
        self.statusItem = item
    }

    @objc public func openStudio() {
        if studioWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Swip Studio"
            window.titlebarAppearsTransparent = true
            window.center()
            window.contentView = NSHostingView(rootView: SwipStudioView())
            self.studioWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        studioWindow?.makeKeyAndOrderFront(nil)
    }

    @objc public func convertFiles() {
        pickFiles { [weak self] urls in
            self?.radial.presentPicker(for: urls, mode: .convert)
        }
    }

    @objc public func openTool() {
        pickFiles { [weak self] urls in
            self?.radial.presentPicker(for: urls, mode: .tools)
        }
    }

    @objc public func fileActions() {
        pickFiles { [weak self] urls in
            self?.radial.presentPicker(for: urls, mode: .actions)
        }
    }

    @objc public func toggleFloatingShelf() {
        FloatingShelfController.shared.toggle()
    }

    @objc public func openSettings() {
        openStudio()
    }

    @objc public func showLogs() {
        let path = DiagnosticLog.currentLogPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func pickFiles(_ completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            completion(panel.urls)
        }
    }
}
