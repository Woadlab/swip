import AppKit
import Combine
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let dragMonitor = DragMonitor()
    private let radial = RadialController()
    private var studioWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var cancellables: Set<AnyCancellable> = []
    private var spinTimer: Timer?
    private var spinAngle: CGFloat = 0
    private var isSpinning = false
    private var noticeTimer: Timer?
    private var restoreTimer: Timer?
    private var previousJobID: UUID?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        DiagnosticLog.start()
        NSApp.setActivationPolicy(.accessory)
        AppSettings.shared.applyAppearance()
        NSApp.applicationIconImage = BrandArtwork.image(size: 256)

        installStatusItem()
        observeBackgroundJobs()

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

    // MARK: - Background Job Menubar Indicator
    private func observeBackgroundJobs() {
        JobRunner.shared.$activeJob
            .receive(on: DispatchQueue.main)
            .sink { [weak self] job in
                self?.handleActiveJobChanged(job)
            }
            .store(in: &cancellables)

        JobRunner.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleJobProgressUpdated()
            }
            .store(in: &cancellables)
    }

    private func handleActiveJobChanged(_ job: Job?) {
        guard let button = statusItem?.button else { return }

        if let job = job {
            // New job started
            if previousJobID != job.id {
                previousJobID = job.id
                restoreTimer?.invalidate()
                restoreTimer = nil

                // Brief notice that retracts
                button.title = " Converting…"
                button.imagePosition = .imageLeading

                noticeTimer?.invalidate()
                noticeTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak button] _ in
                    Task { @MainActor in
                        button?.title = ""
                        button?.imagePosition = .imageOnly
                    }
                }
            }

            button.toolTip = "\(job.title): \(job.detail)"
            startSpinning()
        } else if previousJobID != nil {
            // Active job finished
            let lastJob = JobRunner.shared.jobs.first
            previousJobID = nil
            noticeTimer?.invalidate()
            noticeTimer = nil
            stopSpinning()

            if let last = lastJob {
                switch last.status {
                case .done:
                    let check = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Done")
                    check?.isTemplate = true
                    button.image = check
                    button.title = " Done"
                    button.imagePosition = .imageLeading
                    button.toolTip = "\(last.detail) converted successfully"

                case .failed(let err):
                    let warn = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Failed")
                    warn?.isTemplate = true
                    button.image = warn
                    button.title = " Failed"
                    button.imagePosition = .imageLeading
                    button.toolTip = "Failed: \(err)"

                default:
                    restoreStandardIcon()
                    return
                }

                // Dwell briefly then return smoothly to normal minimal icon
                restoreTimer?.invalidate()
                restoreTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.restoreStandardIcon()
                    }
                }
            } else {
                restoreStandardIcon()
            }
        }
    }

    private func handleJobProgressUpdated() {
        guard let job = JobRunner.shared.activeJob, let button = statusItem?.button else { return }
        let pct = Int(job.progress * 100)
        if pct > 0 && pct < 100 {
            button.toolTip = "\(job.title): \(job.detail) (\(pct)%)"
        }
    }

    private func startSpinning() {
        guard !isSpinning else { return }
        isSpinning = true
        spinTimer?.invalidate()
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSpinning, let button = self.statusItem?.button else { return }
                self.spinAngle += (2 * .pi) / 30.0
                if self.spinAngle >= 2 * .pi { self.spinAngle -= 2 * .pi }
                button.image = BrandArtwork.image(size: 18, angle: self.spinAngle, template: true)
            }
        }
    }

    private func stopSpinning() {
        isSpinning = false
        spinTimer?.invalidate()
        spinTimer = nil
        spinAngle = 0
    }

    private func restoreStandardIcon() {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = BrandArtwork.image(size: 18, template: true)
        button.toolTip = "Swip: Hold Shift while dragging a file to convert"
    }
}
