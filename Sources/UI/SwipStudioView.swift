import AppKit
import SwiftUI

public struct SwipStudioView: View {
    @ObservedObject var jobRunner = JobRunner.shared
    @ObservedObject var settings = AppSettings.shared
    @SwipState private var selectedTab: StudioTab = .convert
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

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 6) {
                // Brand Header
                HStack(spacing: 10) {
                    Image(nsImage: BrandArtwork.image(size: 32))
                        .resizable()
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Swip")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Offline File Converter")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Navigation Items
                ForEach(StudioTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            Spacer()
                            if tab == .history && !jobRunner.jobs.isEmpty {
                                Text("\(jobRunner.jobs.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.18), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Theme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(selectedTab == tab ? Theme.accent : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }

                Spacer()

                // Privacy Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                        Text("100% Local & Offline")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("Zero cloud uploads. Everything processes privately on your Mac.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(12)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
            .frame(minWidth: 200, maxWidth: 220)
        } detail: {
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
        .frame(minWidth: 840, minHeight: 560)
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
                    .fill(isTargeted ? Theme.accent.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isTargeted ? Theme.accent : Color.white.opacity(0.12), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [6, 4]))
                    )

                if droppedURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                        VStack(spacing: 4) {
                            Text("Drag & Drop Files Here")
                                .font(.system(size: 16, weight: .bold))
                            Text("Or hold Shift while dragging anywhere in Finder for zero-click conversions")
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
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
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
                        Text("Choose Output Format")
                            .font(.system(size: 14, weight: .bold))
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
                        Text("No shared conversion target available for the selected formats.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 10)], spacing: 10) {
                            ForEach(targets) { target in
                                Button(action: { selectedTarget = target }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: target.category.symbol)
                                            .font(.system(size: 20))
                                            .foregroundStyle(selectedTarget == target ? .white : Theme.accent)
                                        Text(target.displayName)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(selectedTarget == target ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        selectedTarget == target
                                            ? AnyShapeStyle(Theme.accent)
                                            : AnyShapeStyle(Color.white.opacity(0.05)),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedTarget == target ? Color.white.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
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
            Text("26 Advanced File Tools")
                .font(.system(size: 18, weight: .bold))

            Text("Compress, crop, trim, split, merge, redact, frame, and optimize completely offline.")
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
                                        .foregroundStyle(Theme.accent)
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
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
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
                Text("Conversion History & Jobs")
                    .font(.system(size: 18, weight: .bold))
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
                            .foregroundStyle(Theme.accent)
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

// MARK: - Settings Workbench
struct SettingsWorkbenchView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Output Location") {
                Picker("Save converted files:", selection: $settings.outputLocation) {
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

            Section("Conversion Quality") {
                HStack {
                    Text("Image Compression Quality:")
                    Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(settings.jpegQuality * 100))%")
                        .frame(width: 40)
                }
            }

            Section("Appearance & Accent") {
                Picker("Accent Color:", selection: $settings.accentTheme) {
                    ForEach(AccentTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 12, height: 12)
                    Text("Controls primary action buttons, tool highlights, and Swip accents.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }

            Section("Feedback & Gestures") {
                Toggle("Play sound effects during drag & completion", isOn: $settings.soundEnabled)
                Toggle("Haptic feedback on petal hover", isOn: $settings.hapticsEnabled)
                Toggle("Launch Swip at login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
