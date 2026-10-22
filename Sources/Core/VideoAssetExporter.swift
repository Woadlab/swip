import AppKit
import Foundation
import SwiftUI

@MainActor
public enum VideoAssetExporter {
    public static func exportAll(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("==> Exporting real Swip UI assets to \(directory.path)...")

        // 1. App Icon with Pastel Indigo + Pastel Slate Gray
        exportAppIcon(to: directory.appendingPathComponent("real-app-icon.png"))

        // 2. Real Radial Wheel: Convert Mode
        exportRadialWheel(
            highlighted: nil,
            mode: .convert,
            title: "hero-image.heic",
            to: directory.appendingPathComponent("real-wheel-convert.png")
        )

        // 3. Real Radial Wheel: Hovered WEBP
        exportRadialWheel(
            highlighted: 0,
            mode: .convert,
            title: "hero-image.heic",
            to: directory.appendingPathComponent("real-wheel-hover.png")
        )

        // 4. Real Radial Wheel: Tools Mode
        exportToolsWheel(
            highlighted: 0,
            title: "Voice_Memo.m4a",
            to: directory.appendingPathComponent("real-wheel-tools.png")
        )

        // 5. Real Swip Studio Window
        exportStudioWindow(to: directory.appendingPathComponent("real-studio-window.png"))

        print("==> Finished exporting all real UI assets.")
    }

    private static func exportAppIcon(to url: URL) {
        let image = BrandArtwork.image(size: 1024)
        var rect = CGRect(origin: .zero, size: CGSize(width: 1024, height: 1024))
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("    [✓] real-app-icon.png (1024x1024)")
    }

    private static func exportRadialWheel(highlighted: Int?, mode: RadialMode, title: String, to url: URL) {
        let formats: [FileFormat] = [.webp, .png, .jpg, .pdf, .tiff, .gif, .bmp, .avif]
        let items = formats.map(RadialItem.init(format:))
        let geometry = RadialGeometry(innerRadius: 74, outerRadius: 170, gap: 4, count: items.count)
        let view = RadialWheelView(
            presentationID: UUID(),
            items: items,
            highlighted: highlighted,
            title: title,
            emptyMessage: "No formats",
            emptyDetail: "",
            geometry: geometry,
            mode: mode,
            animateEntrance: false
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        renderView(view, size: NSSize(width: 440, height: 440), to: url)
        print("    [✓] \(url.lastPathComponent)")
    }

    private static func exportToolsWheel(highlighted: Int?, title: String, to url: URL) {
        let tools: [ToolID] = [
            .editMetadata, .trimAudio, .normalizeAudio, .redactAudio,
            .compress, .audioChannels, .audioToVideo, .extractArchive
        ]
        let items = tools.map(RadialItem.init(tool:))
        let geometry = RadialGeometry(innerRadius: 74, outerRadius: 170, gap: 4, count: items.count)
        let view = RadialWheelView(
            presentationID: UUID(),
            items: items,
            highlighted: highlighted,
            title: title,
            emptyMessage: "No tools",
            emptyDetail: "",
            geometry: geometry,
            mode: .tools,
            animateEntrance: false
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        renderView(view, size: NSSize(width: 440, height: 440), to: url)
        print("    [✓] \(url.lastPathComponent)")
    }

    private static func exportStudioWindow(to url: URL) {
        let view = ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                // macOS Titlebar
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)
                    Spacer()
                    Text("Swip Studio")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.02))

                Divider()

                SwipStudioView()
            }
        }
        .frame(width: 880, height: 560)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)

        renderView(view, size: NSSize(width: 880, height: 560), to: url)
        print("    [✓] real-studio-window.png")
    }

    private static func renderView<V: View>(_ view: V, size: NSSize, to url: URL) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .darkAqua)

        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        window.layoutIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
