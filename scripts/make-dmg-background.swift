import AppKit

/// Renders the installer DMG window background (1x and @2x).
/// Usage: make-dmg-background <output-dir> <version>
///
/// Layout contract with scripts/dmg-settings.py: the window content is 660×420 points,
/// the app icon sits at (170, 212) and the Applications link at (490, 212),
/// both 128 pt, measured from the top-left corner to the icon center.
@main
struct MakeDMGBackground {
    static let size = CGSize(width: 660, height: 420)
    static let appX: CGFloat = 170
    static let appsX: CGFloat = 490
    static let iconY: CGFloat = 212

    static func main() throws {
        let args = CommandLine.arguments
        let out = URL(fileURLWithPath: args.count > 1 ? args[1] : ".")
        let version = args.count > 2 ? args[2] : ""
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for scale in [1, 2] {
            let rep = render(scale: CGFloat(scale), version: version)
            let name = scale == 1 ? "background.png" : "background@2x.png"
            try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
        }
    }

    static func render(scale: CGFloat, version: String) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(version: version)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Converts a top-left based point (Finder coordinates) to drawing space.
    static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }

    static func draw(version: String) {
        let ctx = NSGraphicsContext.current!.cgContext
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let indigo = NSColor(srgbRed: 0.44, green: 0.48, blue: 0.96, alpha: 1)
        let ink = NSColor(srgbRed: 0.09, green: 0.10, blue: 0.16, alpha: 1)

        // Base: soft paper white, cooling slightly toward the bottom. Finder draws
        // icon labels in black over a background picture (even in Dark Mode), so
        // the window must stay light for the labels to read.
        let base = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 0.988, green: 0.988, blue: 0.996, alpha: 1).cgColor,
            NSColor(srgbRed: 0.930, green: 0.936, blue: 0.965, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(base, start: p(0, 0), end: p(0, size.height), options: [])

        // Indigo bloom behind the app icon.
        let bloom = CGGradient(colorsSpace: space, colors: [
            indigo.withAlphaComponent(0.13).cgColor, indigo.withAlphaComponent(0).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(bloom, startCenter: p(appX, iconY), startRadius: 0,
                               endCenter: p(appX, iconY), endRadius: 210, options: [])

        // A faint radial wheel around the app, like the HUD around a dragged file.
        // The east petal, toward Applications, is the selected one.
        let ring = BrandArtwork.WheelSpec(inner: 80, outer: 116, gap: 7, corner: 9, pop: 5, dot: 0)
        for i in 0..<8 {
            let selected = i == 0
            let path = BrandArtwork.petal(center: p(appX, iconY), angle: CGFloat(i) * .pi / 4,
                                          spec: ring, size: 1, popped: selected)
            ctx.addPath(path)
            ctx.setFillColor(indigo.withAlphaComponent(selected ? 0.20 : 0.065).cgColor)
            ctx.fillPath()
        }

        // Drag path: dots growing toward Applications, then an arrowhead.
        let start = p(appX + 128, iconY)
        let end = p(appsX - 82, iconY)
        let dots = 7
        for i in 0..<dots {
            let t = CGFloat(i) / CGFloat(dots - 1)
            let x = start.x + (end.x - 16 - start.x) * t
            let r: CGFloat = 1.8 + 1.1 * t
            indigo.withAlphaComponent(0.30 + 0.60 * t).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - r, y: start.y - r, width: r * 2, height: r * 2)).fill()
        }
        let head = NSBezierPath()
        head.move(to: CGPoint(x: end.x, y: end.y))
        head.line(to: CGPoint(x: end.x - 9, y: end.y + 6))
        head.line(to: CGPoint(x: end.x - 9, y: end.y - 6))
        head.close()
        head.lineJoinStyle = .round
        head.lineWidth = 2
        indigo.setFill()
        indigo.setStroke()
        head.fill()
        head.stroke()

        // Copy.
        func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat, kern: CGFloat = 0) {
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: para,
                .kern: kern,
            ]
            let str = NSAttributedString(string: s, attributes: attrs)
            let h = str.size().height
            str.draw(in: NSRect(x: 0, y: MakeDMGBackground.size.height - centerY - h / 2,
                                width: MakeDMGBackground.size.width, height: h))
        }
        text("Drag Swip into Applications", size: 19, weight: .semibold, color: ink, centerY: 52, kern: -0.2)
        text("Then hold ⇧ Shift and drag any file to summon the wheel.", size: 12.5, weight: .regular,
             color: ink.withAlphaComponent(0.55), centerY: 78)

        let footer = version.isEmpty ? "Local-first file conversions for macOS" : "Swip \(version)  ·  Local-first file conversions for macOS"
        text(footer, size: 11, weight: .medium, color: ink.withAlphaComponent(0.36), centerY: 392, kern: 0.2)
    }
}
