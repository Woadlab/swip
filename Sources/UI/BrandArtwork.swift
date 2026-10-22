import AppKit

public enum BrandArtwork {
    public static func image(size: CGFloat, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let ctx = NSGraphicsContext.current?.cgContext

            if !template {
                // Background dark gradient squircle
                let cornerRadius = s * 0.22
                let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: cornerRadius, yRadius: cornerRadius)

                let gradient = NSGradient(colors: [
                    NSColor(srgbRed: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
                    NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
                ])
                gradient?.draw(in: bgPath, angle: -45)

                // Outer border glow
                NSColor(srgbRed: 0.44, green: 0.48, blue: 0.96, alpha: 0.35).setStroke()
                bgPath.lineWidth = s * 0.02
                bgPath.stroke()

                // Vibrant Swip gesture swirl
                let center = CGPoint(x: s * 0.5, y: s * 0.5)
                let radius = s * 0.26

                // Arc 1 - vibrant pastel indigo
                ctx?.saveGState()
                ctx?.setLineWidth(s * 0.07)
                ctx?.setLineCap(.round)
                ctx?.setStrokeColor(NSColor(srgbRed: 0.44, green: 0.48, blue: 0.96, alpha: 1.0).cgColor)
                ctx?.addArc(center: center, radius: radius, startAngle: .pi * 0.2, endAngle: .pi * 0.9, clockwise: false)
                ctx?.strokePath()
                ctx?.restoreGState()

                // Arc 2 - refined pastel slate / silver gray
                ctx?.saveGState()
                ctx?.setLineWidth(s * 0.07)
                ctx?.setLineCap(.round)
                ctx?.setStrokeColor(NSColor(srgbRed: 0.80, green: 0.84, blue: 0.92, alpha: 1.0).cgColor)
                ctx?.addArc(center: center, radius: radius, startAngle: .pi * 1.2, endAngle: .pi * 1.9, clockwise: false)
                ctx?.strokePath()
                ctx?.restoreGState()

                // Center tactile dot
                let dotRect = NSRect(x: s * 0.42, y: s * 0.42, width: s * 0.16, height: s * 0.16)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else {
                // Monochrome Menu bar icon
                let strokeColor = NSColor.labelColor
                strokeColor.setStroke()
                strokeColor.setFill()

                let center = CGPoint(x: s * 0.5, y: s * 0.5)
                let radius = s * 0.32

                // Segmented ring
                ctx?.saveGState()
                ctx?.setLineWidth(s * 0.12)
                ctx?.setLineCap(.round)
                ctx?.setStrokeColor(strokeColor.cgColor)
                ctx?.addArc(center: center, radius: radius, startAngle: .pi * 0.25, endAngle: .pi * 0.85, clockwise: false)
                ctx?.strokePath()
                ctx?.restoreGState()

                ctx?.saveGState()
                ctx?.setLineWidth(s * 0.12)
                ctx?.setLineCap(.round)
                ctx?.setStrokeColor(strokeColor.cgColor)
                ctx?.addArc(center: center, radius: radius, startAngle: .pi * 1.25, endAngle: .pi * 1.85, clockwise: false)
                ctx?.strokePath()
                ctx?.restoreGState()

                // Center core
                let dotRect = NSRect(x: s * 0.41, y: s * 0.41, width: s * 0.18, height: s * 0.18)
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
        image.isTemplate = template
        return image
    }
}
