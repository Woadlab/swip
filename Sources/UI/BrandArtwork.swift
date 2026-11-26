import AppKit

/// The Swip mark: the 8-petal radial wheel frozen mid-gesture. The center dot is
/// the dragged file; the selected petal (north-east) pops outward exactly like
/// the hovered petal in the real HUD.
public enum BrandArtwork {
    /// Brand indigo (Pastel Indigo, the default accent).
    static let indigo = NSColor(srgbRed: 0.44, green: 0.48, blue: 0.96, alpha: 1)
    static let indigoLight = NSColor(srgbRed: 0.62, green: 0.65, blue: 1.00, alpha: 1)
    static let silver = NSColor(srgbRed: 0.84, green: 0.87, blue: 0.95, alpha: 1)

    /// Number of petals and the index of the selected one (0 = east, counter-clockwise).
    static let petalCount = 8
    static let selectedPetal = 1

    public static func image(size: CGFloat, angle: CGFloat = 0, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = rect.width

            if angle != 0 {
                ctx.translateBy(x: s * 0.5, y: s * 0.5)
                ctx.rotate(by: angle)
                ctx.translateBy(x: -s * 0.5, y: -s * 0.5)
            }

            if template {
                drawTemplate(in: ctx, size: s)
            } else {
                drawAppIcon(in: ctx, size: s)
            }
            return true
        }
        image.isTemplate = template
        return image
    }

    // MARK: - App icon

    private static func drawAppIcon(in ctx: CGContext, size s: CGFloat) {
        // macOS icon grid: an 824/1024 body, centered, with a soft drop shadow.
        let inset = s * (100.0 / 1024.0)
        let body = CGRect(x: inset, y: inset + s * 0.008, width: s - inset * 2, height: s - inset * 2)
        let bodyPath = squircle(in: body)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                      color: NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(bodyPath)
        ctx.setFillColor(NSColor(srgbRed: 0.07, green: 0.08, blue: 0.12, alpha: 1).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.clip()

        // Deep ink gradient, lighter at the top like a lit surface.
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ink = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 0.17, green: 0.18, blue: 0.29, alpha: 1).cgColor,
            NSColor(srgbRed: 0.06, green: 0.065, blue: 0.11, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(ink, start: CGPoint(x: s * 0.5, y: body.maxY), end: CGPoint(x: s * 0.5, y: body.minY), options: [])

        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let spec = WheelSpec.appIcon
        let selectedAngle = CGFloat(selectedPetal) * (.pi * 2 / CGFloat(petalCount))
        let selectedPoint = point(center, (spec.inner + spec.outer) / 2 * s + spec.pop * s, selectedAngle)

        // Indigo bloom behind the selected petal.
        let bloom = CGGradient(colorsSpace: space, colors: [
            indigo.withAlphaComponent(0.55).cgColor,
            indigo.withAlphaComponent(0).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(bloom, startCenter: selectedPoint, startRadius: 0,
                               endCenter: selectedPoint, endRadius: s * 0.36, options: [])

        // Hairline highlight along the top edge.
        ctx.addPath(bodyPath)
        ctx.setLineWidth(s * 0.008)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let rim = CGGradient(colorsSpace: space, colors: [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray, locations: [0, 0.5])!
        ctx.drawLinearGradient(rim, start: CGPoint(x: s * 0.5, y: body.maxY), end: CGPoint(x: s * 0.5, y: body.minY), options: [])
        ctx.restoreGState()

        drawWheel(in: ctx, center: center, spec: .appIcon, size: s,
                  rest: silver.withAlphaComponent(0.17), selected: nil, dot: .white, glow: true)
    }

    // MARK: - Menu bar template

    private static func drawTemplate(in ctx: CGContext, size s: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        drawWheel(in: ctx, center: center, spec: .template, size: s,
                  rest: NSColor.black.withAlphaComponent(0.42), selected: .black, dot: .black, glow: false)
    }

    // MARK: - Shared wheel

    /// Proportions of the wheel, as fractions of the canvas size.
    public struct WheelSpec {
        public var inner: CGFloat
        public var outer: CGFloat
        public var gap: CGFloat
        public var corner: CGFloat
        public var pop: CGFloat
        public var dot: CGFloat

        public static let appIcon = WheelSpec(inner: 0.115, outer: 0.300, gap: 0.022, corner: 0.020, pop: 0.030, dot: 0.050)
        public static let template = WheelSpec(inner: 0.170, outer: 0.455, gap: 0.070, corner: 0.035, pop: 0.040, dot: 0.090)
        /// For the small SwiftUI tile in the menu bar panel (no icon margin).
        public static let tile = WheelSpec(inner: 0.150, outer: 0.375, gap: 0.035, corner: 0.028, pop: 0.035, dot: 0.065)
    }

    private static func drawWheel(in ctx: CGContext, center: CGPoint, spec: WheelSpec, size s: CGFloat,
                                  rest: NSColor, selected: NSColor?, dot: NSColor, glow: Bool) {
        let slot = CGFloat.pi * 2 / CGFloat(petalCount)
        ctx.saveGState()

        for i in 0..<petalCount where i != selectedPetal {
            ctx.addPath(petal(center: center, angle: CGFloat(i) * slot, spec: spec, size: s, popped: false))
            ctx.setFillColor(rest.cgColor)
            ctx.fillPath()
        }

        // Selected petal, popped outward.
        let selectedAngle = CGFloat(selectedPetal) * slot
        let selectedPath = petal(center: center, angle: selectedAngle, spec: spec, size: s, popped: true)
        ctx.saveGState()
        if let selected {
            ctx.addPath(selectedPath)
            ctx.setFillColor(selected.cgColor)
            ctx.fillPath()
        } else {
            ctx.setShadow(offset: .zero, blur: s * 0.05, color: indigo.withAlphaComponent(0.85).cgColor)
            ctx.addPath(selectedPath)
            ctx.setFillColor(indigo.cgColor)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.addPath(selectedPath)
            ctx.clip()
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            let gradient = CGGradient(colorsSpace: space, colors: [indigoLight.cgColor, indigo.cgColor] as CFArray, locations: [0, 1])!
            let outer = point(center, (spec.outer + spec.pop) * s, selectedAngle)
            let inner = point(center, (spec.inner + spec.pop) * s, selectedAngle)
            ctx.drawLinearGradient(gradient, start: outer, end: inner, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()

        // The dragged file, resting in the hub.
        let r = spec.dot * s
        ctx.saveGState()
        if glow {
            ctx.setShadow(offset: .zero, blur: s * 0.03, color: NSColor.white.withAlphaComponent(0.5).cgColor)
        }
        ctx.setFillColor(dot.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.restoreGState()

        ctx.restoreGState()
    }

    /// One petal: an annular sector with parallel gaps and rounded corners,
    /// the same shape as the petals in the radial HUD. `angle` is the petal's
    /// bisector, in the path's own coordinate system.
    public static func petal(center: CGPoint, angle: CGFloat, spec: WheelSpec, size s: CGFloat, popped: Bool) -> CGPath {
        let half = CGFloat.pi / CGFloat(petalCount)
        let corner = spec.corner * s
        let h = spec.gap * s / 2 + corner
        let ri = spec.inner * s + corner
        let ro = spec.outer * s - corner
        let shift = popped ? spec.pop * s : 0
        let c = CGPoint(x: center.x + cos(angle) * shift, y: center.y + sin(angle) * shift)

        let core = CGMutablePath()
        core.move(to: point(c, ri, angle - half + asin(min(h / ri, 1))))
        core.addLine(to: point(c, ro, angle - half + asin(h / ro)))
        core.addArc(center: c, radius: ro, startAngle: angle - half + asin(h / ro),
                    endAngle: angle + half - asin(h / ro), clockwise: false)
        core.addLine(to: point(c, ri, angle + half - asin(min(h / ri, 1))))
        core.addArc(center: c, radius: ri, startAngle: angle + half - asin(min(h / ri, 1)),
                    endAngle: angle - half + asin(min(h / ri, 1)), clockwise: true)
        core.closeSubpath()

        let rounded = core.copy(strokingWithWidth: corner * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return core.union(rounded)
    }

    // MARK: - Geometry

    static func point(_ c: CGPoint, _ r: CGFloat, _ a: CGFloat) -> CGPoint {
        CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
    }

    /// Superellipse approximating Apple's continuous-corner icon shape.
    static func squircle(in rect: CGRect, exponent n: CGFloat = 4.2) -> CGPath {
        let path = CGMutablePath()
        let a = rect.width / 2, b = rect.height / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 256
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps) * .pi * 2
            let ct = cos(t), st = sin(t)
            let x = c.x + a * copysign(pow(abs(ct), 2 / n), ct)
            let y = c.y + b * copysign(pow(abs(st), 2 / n), st)
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()
        return path
    }
}
