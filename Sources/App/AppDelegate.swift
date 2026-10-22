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
    private var spinTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?
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
                Task { @MainActor in
                    self?.handleActiveJobChanged(job)
                }
            }
            .store(in: &cancellables)

        JobRunner.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleJobProgressUpdated()
                }
            }
            .store(in: &cancellables)
    }

    private func handleActiveJobChanged(_ job: Job?) {
        guard let button = statusItem?.button else { return }

        if let job = job {
            // New job started
            if previousJobID != job.id {
                previousJobID = job.id
                restoreTask?.cancel()
                restoreTask = nil

                // Brief notice that retracts smoothly
                button.title = " Converting…"
                button.imagePosition = .imageLeading

                noticeTask?.cancel()
                noticeTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    guard !Task.isCancelled else { return }
                    button.title = ""
                    button.imagePosition = .imageOnly
                }
            }

            button.toolTip = "\(job.title): \(job.detail)"
            startSpinning()
        } else if previousJobID != nil {
            // Active job finished
            let lastJob = JobRunner.shared.jobs.first
            previousJobID = nil
            noticeTask?.cancel()
            noticeTask = nil
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
                restoreTask?.cancel()
                restoreTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    self.restoreStandardIcon()
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
        guard spinTask == nil else { return }
        spinTask = Task { @MainActor in
            var angle: CGFloat = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_333_333) // ~30 fps
                guard !Task.isCancelled, let button = self.statusItem?.button else { break }
                angle += (2 * .pi) / 30.0
                if angle >= 2 * .pi { angle -= 2 * .pi }
                button.image = BrandArtwork.image(size: 18, angle: angle, template: true)
            }
        }
    }

    private func stopSpinning() {
        spinTask?.cancel()
        spinTask = nil
    }

    private func restoreStandardIcon() {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = BrandArtwork.image(size: 18, template: true)
        button.toolTip = "Swip: Hold Shift while dragging a file to convert"
    }
}
