import AppKit
import SwiftUI

/// Lets the menu bar panel open the Studio on a specific tab.
public final class StudioRouter: ObservableObject {
    public static let shared = StudioRouter()
    @Published public var tab: SwipStudioView.StudioTab = .convert
    private init() {}
}

public struct SwipStudioView: View {
    @ObservedObject var jobRunner = JobRunner.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var router = StudioRouter.shared
    private var selectedTab: StudioTab {
        get { router.tab }
        nonmutating set { router.tab = newValue }
    }
    @SwipState private var droppedURLs: [URL] = []
    @SwipState private var selectedTargetFormat: FileFormat?
    @SwipState private var isDropTargeted = false
    @SwipState private var searchQuery = ""

    public enum StudioTab: String, CaseIterable, Identifiable {
        case convert = "Convert"
        case tools = "Tools"
        case history = "History"
        case settings = "Settings"

        public var id: String { rawValue }

        public var symbol: String {
            switch self {
            case .convert: return "arrow.triangle.2.circlepath"
            case .tools: return "wrench.and.screwdriver"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    public init() {}

    /// Height reserved for the transparent title bar (traffic lights).
    private static let titlebarInset: CGFloat = 40

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 236)
                .frame(maxHeight: .infinity)
                .background(VisualEffectBackdrop(material: .sidebar))

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)

            Group {
                switch selectedTab {
                case .convert:
                    ConvertWorkbenchView(droppedURLs: $droppedURLs)
                case .tools:
                    ToolsWorkbenchView(droppedURLs: $droppedURLs)
                case .history:
                    HistoryWorkbenchView()
                case .settings:
                    SettingsWorkbenchView()
                }
            }
            .padding(.top, Self.titlebarInset - 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea()
        .frame(minWidth: 860, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: BrandArtwork.image(size: 32))
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Swip")
                        .font(.system(size: 14, weight: .semibold))
                    Text("File converter for macOS")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, Self.titlebarInset)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                ForEach(StudioTab.allCases) { tab in
                    SidebarRow(
                        title: tab.rawValue,
                        symbol: tab.symbol,
                        count: tab == .history && !jobRunner.jobs.isEmpty ? jobRunner.jobs.count : nil,
                        selected: selectedTab == tab
                    ) { selectedTab = tab }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text("Everything runs on this Mac. Files are never uploaded.")
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

/// Sidebar navigation row: the whole row is the hit target, hover and
/// selection are small surface steps rather than colored fills.
private struct SidebarRow: View {
    let title: String
    let symbol: String
    let count: Int?
    let selected: Bool
    let action: () -> Void
    @SwipState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Theme.accent : Color.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.85))
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.08 : (hovering ? 0.04 : 0)))
                    .padding(.vertical, 1)
            }
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Convert Workbench
struct ConvertWorkbenchView: View {
    @Binding var droppedURLs: [URL]
    @ObservedObject var jobRunner = JobRunner.shared
    @SwipState private var isTargeted = false
    @SwipState private var selectedTarget: FileFormat?

    var body: some View {
        VStack(spacing: 16) {
            // Drop Zone Area
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isTargeted ? Theme.accent.opacity(0.08) : Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isTargeted ? Theme.accent : Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 4]))
                    )

                if droppedURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                        VStack(spacing: 4) {
                            Text("Drop files to convert")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Or hold ⇧ while dragging a file anywhere on your Mac")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Button("Choose Files…") {
                            pickFiles()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(32)
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Text("\(droppedURLs.count) file\(droppedURLs.count == 1 ? "" : "s") selected")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Button("Clear") {
                                droppedURLs.removeAll()
                                selectedTarget = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(droppedURLs, id: \.self) { url in
                                    HStack(spacing: 8) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(url.lastPathComponent)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                            Text(FileSizeFormatter.string(FileSizeFormatter.size(of: url)))
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 50)
                    }
                }
            }
            .frame(height: droppedURLs.isEmpty ? 220 : 120)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                if !droppedURLs.contains(url) { droppedURLs.append(url) }
                            }
                        }
                    }
                }
                return true
            }

            // Available Targets Grid
            if !droppedURLs.isEmpty {
                let formats = droppedURLs.compactMap(FileFormat.detect)
                let targets = ConversionMatrix.targets(for: formats)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Convert to")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if let selectedTarget = selectedTarget {
                            Button("Convert All to \(selectedTarget.displayName)") {
                                JobRunner.shared.convert(droppedURLs, to: selectedTarget)
                                droppedURLs.removeAll()
                                self.selectedTarget = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if targets.isEmpty {
                        Text("These files have no output format in common")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 10)], spacing: 10) {
                            ForEach(targets) { target in
                                Button(action: { selectedTarget = target }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: target.category.symbol)
                                            .font(.system(size: 18))
                                            .foregroundStyle(selectedTarget == target ? Theme.accent : Color.secondary)
                                        Text(target.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedTarget == target
                                            ? AnyShapeStyle(Theme.accent.opacity(0.12))
                                            : AnyShapeStyle(Color.primary.opacity(0.04)),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(selectedTarget == target ? Theme.accent.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: selectedTarget == target ? 1 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK {
                droppedURLs = panel.urls
            }
        }
    }
}

// MARK: - Tools Workbench
struct ToolsWorkbenchView: View {
    @Binding var droppedURLs: [URL]
    @SwipState private var selectedTool: ToolID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tools")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(ToolID.allCases.count)")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text("Compress, crop, trim, split, merge, redact and frame files without leaving your Mac")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)], spacing: 12) {
                    ForEach(ToolID.allCases) { tool in
                        Button(action: {
                            if droppedURLs.isEmpty {
                                pickFileForTool(tool)
                            } else {
                                ToolWindowManager.shared.open(tool, files: droppedURLs)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: tool.symbol)
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                Text(tool.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(tool.categories.map(\.title).joined(separator: ", "))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
    }

    private func pickFileForTool(_ tool: ToolID) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = tool.arity == .multiple || tool.arity == .any
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK && !panel.urls.isEmpty {
                ToolWindowManager.shared.open(tool, files: panel.urls)
            }
        }
    }
}

// MARK: - History Workbench
struct HistoryWorkbenchView: View {
    @ObservedObject var jobRunner = JobRunner.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("History")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if !jobRunner.jobs.isEmpty {
                    Button("Clear Finished") {
                        jobRunner.clearFinished()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                }
            }

            if jobRunner.jobs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No conversions yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Files you convert via drag or in-app will appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(jobRunner.jobs) { job in
                    HStack(spacing: 12) {
                        Image(systemName: job.symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(job.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(job.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if job.status == .running {
                                ProgressView(value: job.progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 160)
                            }
                        }

                        Spacer()

                        switch job.status {
                        case .waiting:
                            Text("Waiting")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        case .running:
                            ProgressView()
                                .controlSize(.small)
                        case .done:
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                if let first = job.outputs.first {
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([first])
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.system(size: 11))
                                }
                            }
                        case .cancelled:
                            Text("Cancelled")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        case .failed(let reason):
                            Text("Failed: \(reason)")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
    }
}

/// A color dot for the accent picker; the selected one gets a ring.
private struct AccentSwatch: View {
    let theme: AccentTheme
    let selected: Bool
    let action: () -> Void
    @SwipState private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: Theme.accentNS(for: theme)))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(selected ? Color(nsColor: Theme.accentNS(for: theme)) : Color.primary.opacity(hovering ? 0.2 : 0), lineWidth: 1.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
        .help(theme.title)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Settings Workbench
struct SettingsWorkbenchView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Output") {
                Picker("Save converted files", selection: $settings.outputLocation) {
                    ForEach(OutputLocation.allCases) { loc in
                        Text(loc.title).tag(loc)
                    }
                }
                .pickerStyle(.radioGroup)

                if settings.outputLocation == .custom {
                    HStack {
                        TextField("Custom folder path", text: $settings.customOutputPath)
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    settings.customOutputPath = url.path
                                }
                            }
                        }
                    }
                }
            }

            Section("Quality") {
                LabeledContent("Image quality") {
                    HStack(spacing: 12) {
                        Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.05)
                            .labelsHidden()
                            .frame(maxWidth: 220)
                        Text("\(Int(settings.jpegQuality * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .fixedSize()
                LabeledContent("Accent color") {
                    HStack(spacing: 10) {
                        ForEach(AccentTheme.allCases) { theme in
                            AccentSwatch(theme: theme, selected: settings.accentTheme == theme) {
                                settings.accentTheme = theme
                            }
                        }
                        Text(settings.accentTheme.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .leading)
                    }
                }
            }

            Section("General") {
                Toggle("Sound effects", isOn: $settings.soundEnabled)
                Toggle("Haptic feedback on the wheel", isOn: $settings.hapticsEnabled)
                Toggle("Open at login", isOn: $settings.launchAtLogin)
                    .disabled(!InstanceGuard.isInstalledCopy)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
