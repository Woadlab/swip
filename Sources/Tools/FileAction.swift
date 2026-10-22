import AppKit
import CryptoKit

public enum FileAction: String, CaseIterable, Hashable, Identifiable {
    case airDrop = "AirDrop"
    case float = "Float"
    case copy = "Copy"
    case move = "Move"
    case copyPath = "Copy Path"
    case terminal = "Terminal"
    case duplicate = "Duplicate"
    case hash = "SHA-256"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .airDrop: return "AIRDROP"
        case .float: return "FLOAT"
        case .copy: return "COPY"
        case .move: return "MOVE"
        case .copyPath: return "COPY PATH"
        case .terminal: return "TERMINAL"
        case .duplicate: return "DUPLICATE"
        case .hash: return "SHA-256"
        }
    }

    public var symbol: String {
        switch self {
        case .airDrop: return "airplayaudio"
        case .float: return "pin.fill"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .copyPath: return "link"
        case .terminal: return "terminal"
        case .duplicate: return "plus.square.on.square"
        case .hash: return "number"
        }
    }

    public var description: String {
        switch self {
        case .airDrop:
            return "Share files and folders through the macOS recipient picker."
        case .float:
            return "Keep files in a floating shelf. Pin it to a screen edge and drag files into another app."
        case .copy:
            return "Copy files to the clipboard, ready to paste in Finder."
        case .move:
            return "Choose a destination folder and move the originals there."
        case .copyPath:
            return "Copy full file paths as text, with one path per line for a selection."
        case .terminal:
            return "Open a folder, or a file's containing folder, in Terminal."
        case .duplicate:
            return "Duplicate original files with copy suffix."
        case .hash:
            return "Calculate SHA-256 hash checksums of selected files."
        }
    }

    public static func duplicateFiles(_ urls: [URL]) throws -> [URL] {
        try urls.map { source in
            let destination = ConversionMatrix.uniqueURL(
                directory: source.deletingLastPathComponent(),
                baseName: ConversionMatrix.strippedBaseName(source.lastPathComponent),
                suffix: "copy",
                ext: source.pathExtension
            )
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        }
    }

    public static func hashReport(_ urls: [URL]) throws -> String {
        try urls.map { url in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { throw SwipError.unreadable(url) }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            var hash = SHA256()
            while let data = try file.read(upToCount: 1_048_576), !data.isEmpty {
                try Task.checkCancellation()
                hash.update(data: data)
            }
            return hash.finalize().map { String(format: "%02x", $0) }.joined() + "  " + url.lastPathComponent
        }.joined(separator: "\n")
    }

    @MainActor
    public func run(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        switch self {
        case .airDrop:
            let picker = NSSharingServicePicker(items: urls)
            if let mouseWindow = NSApp.keyWindow ?? NSApp.windows.first {
                let rect = NSRect(origin: mouseWindow.mouseLocationOutsideOfEventStream, size: .zero)
                picker.show(relativeTo: rect, of: mouseWindow.contentView ?? NSView(), preferredEdge: .minY)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }

        case .float:
            FloatingShelfController.shared.add(urls: urls)

        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(urls as [NSURL])
            SoundManager.shared.playSuccess()

        case .move:
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.prompt = "Move Here"
            panel.title = "Move \(urls.count) File\(urls.count == 1 ? "" : "s")"
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { response in
                guard response == .OK, let destinationDir = panel.url else { return }
                Task {
                    for url in urls {
                        let target = destinationDir.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.moveItem(at: url, to: target)
                    }
                    SoundManager.shared.playSuccess()
                }
            }

        case .copyPath:
            NSPasteboard.general.clearContents()
            let paths = urls.map(\.path).joined(separator: "\n")
            NSPasteboard.general.setString(paths, forType: .string)
            SoundManager.shared.playSuccess()

        case .terminal:
            for url in urls {
                let dir = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.open([dir], withApplicationAt: terminalURL, configuration: config, completionHandler: nil)
                } else {
                    NSWorkspace.shared.open(dir)
                }
            }

        case .duplicate:
            JobRunner.shared.run(title: "Duplicate", detail: "\(urls.count) files") { _ in
                try Self.duplicateFiles(urls)
            }

        case .hash:
            Task {
                do {
                    let report = try await Task.detached(priority: .userInitiated) {
                        try Self.hashReport(urls)
                    }.value
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    let alert = NSAlert()
                    alert.messageText = "SHA-256 Copied"
                    alert.informativeText = report
                    alert.runModal()
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }
}
