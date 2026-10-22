import AppKit
import Foundation
import ServiceManagement

public enum CompressionPreset: String, CaseIterable, Identifiable {
    case balanced
    case strong

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var imageQuality: Double { self == .balanced ? 0.72 : 0.5 }
    public var videoScale: Double { self == .balanced ? 1.0 : 0.75 }
    public var videoBitrateFactor: Double { self == .balanced ? 0.6 : 0.35 }
    public var audioBitrate: Int { self == .balanced ? 128_000 : 64_000 }
}

public enum AccentTheme: String, CaseIterable, Identifiable {
    case pastelIndigo = "pastelIndigo"
    case pastelMint = "pastelMint"
    case pastelRose = "pastelRose"
    case system = "system"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pastelIndigo: return "Pastel Indigo (Default)"
        case .pastelMint: return "Pastel Mint"
        case .pastelRose: return "Pastel Rose"
        case .system: return "macOS Accent"
        }
    }
}

public enum OutputLocation: String, CaseIterable, Identifiable {
    case besideOriginal = "besideOriginal"
    case downloads = "downloads"
    case desktop = "desktop"
    case custom = "custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .besideOriginal: return "Beside Original File"
        case .downloads: return "Downloads Folder"
        case .desktop: return "Desktop"
        case .custom: return "Custom Folder…"
        }
    }

    public func directory(for source: URL) -> URL {
        switch self {
        case .besideOriginal:
            let parent = source.deletingLastPathComponent()
            let path = parent.path
            // Guard: Never output inside the Trash or ephemeral temporary folders
            if path.contains("/.Trash") || path.contains("/.Trashes") || path.hasPrefix("/private/var") || path.hasPrefix("/var/folders") || path == "/tmp" || path.hasPrefix("/private/tmp") {
                return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? parent
            }
            return parent
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? source.deletingLastPathComponent()
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? source.deletingLastPathComponent()
        case .custom:
            if let customPath = UserDefaults.standard.string(forKey: "customOutputPath"),
               !customPath.isEmpty {
                let url = URL(fileURLWithPath: customPath)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            return source.deletingLastPathComponent()
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published public var outputLocation: OutputLocation {
        didSet { defaults.set(outputLocation.rawValue, forKey: "outputLocation") }
    }

    @Published public var customOutputPath: String {
        didSet { defaults.set(customOutputPath, forKey: "customOutputPath") }
    }

    @Published public var ffmpegPath: String {
        didSet { defaults.set(ffmpegPath, forKey: "ffmpegPath") }
    }

    @Published public var compressionPreset: CompressionPreset {
        didSet { defaults.set(compressionPreset.rawValue, forKey: "compressionPreset") }
    }

    @Published public var compressionResizeLongEdge: Int {
        didSet { defaults.set(compressionResizeLongEdge, forKey: "compressionResizeLongEdge") }
    }

    @Published public var jpegQuality: Double {
        didSet { defaults.set(jpegQuality, forKey: "jpegQuality") }
    }

    @Published public var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published public var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    @Published public var excludedApplications: [String: String] {
        didSet { defaults.set(excludedApplications, forKey: "excludedApplications") }
    }

    @Published public var accentTheme: AccentTheme {
        didSet {
            defaults.set(accentTheme.rawValue, forKey: "accentTheme")
            objectWillChange.send()
        }
    }

    @Published public var appearance: String {
        didSet {
            defaults.set(appearance, forKey: "appearance")
            applyAppearance()
        }
    }

    private init() {
        let loc = defaults.string(forKey: "outputLocation").flatMap(OutputLocation.init) ?? .besideOriginal
        self.outputLocation = loc
        self.customOutputPath = defaults.string(forKey: "customOutputPath") ?? ""
        self.ffmpegPath = defaults.string(forKey: "ffmpegPath") ?? ""
        self.compressionPreset = CompressionPreset(rawValue: defaults.string(forKey: "compressionPreset") ?? "") ?? .balanced
        self.compressionResizeLongEdge = defaults.integer(forKey: "compressionResizeLongEdge")
        self.jpegQuality = defaults.object(forKey: "jpegQuality") != nil ? defaults.double(forKey: "jpegQuality") : 0.85
        self.soundEnabled = defaults.object(forKey: "soundEnabled") != nil ? defaults.bool(forKey: "soundEnabled") : true
        self.hapticsEnabled = defaults.object(forKey: "hapticsEnabled") != nil ? defaults.bool(forKey: "hapticsEnabled") : true
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.excludedApplications = defaults.dictionary(forKey: "excludedApplications") as? [String: String] ?? [:]
        self.appearance = defaults.string(forKey: "appearance") ?? "system"
        self.accentTheme = defaults.string(forKey: "accentTheme").flatMap(AccentTheme.init) ?? .pastelIndigo
    }

    public func applyAppearance() {
        switch appearance {
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                DiagnosticLog.log("Login item update error: \(error)")
            }
        }
    }
}
