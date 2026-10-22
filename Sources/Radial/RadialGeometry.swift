import CoreGraphics
import Foundation
import SwiftUI

public struct RadialGeometry: Equatable, Sendable {
    public var innerRadius: CGFloat = 68
    public var outerRadius: CGFloat = 160
    public var gap: CGFloat = 4
    public var count: Int

    public init(innerRadius: CGFloat = 68, outerRadius: CGFloat = 160, gap: CGFloat = 4, count: Int) {
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.gap = gap
        self.count = count
    }

    public var slice: CGFloat { 2 * .pi / CGFloat(max(count, 1)) }

    public var corner: CGFloat {
        let wanted: CGFloat = count > 8 ? 8 : 12
        let limit = (innerRadius * sin(slice * 0.34) - gap / 2) / (1 - sin(slice * 0.34))
        return max(3, min(wanted, limit))
    }

    public var labelRadius: CGFloat { (innerRadius + outerRadius) * 0.525 }

    public var labelWidth: CGFloat {
        let chord = 2 * labelRadius * sin(slice / 2)
        return max(32, chord - 6)
    }

    public func midAngle(for index: Int) -> CGFloat {
        CGFloat.pi / 2 - slice * CGFloat(index)
    }

    public func angles(for index: Int) -> (start: CGFloat, end: CGFloat) {
        let end = CGFloat.pi / 2 - slice * CGFloat(index) + slice / 2
        return (end - slice, end)
    }

    public func midpoint(for index: Int, in rect: CGRect) -> CGPoint {
        let mid = midAngle(for: index)
        return CGPoint(x: rect.midX + cos(mid) * labelRadius, y: rect.midY - sin(mid) * labelRadius)
    }

    public func index(at offset: CGPoint) -> Int? {
        guard count > 0 else { return nil }
        let distance = sqrt(offset.x * offset.x + offset.y * offset.y)
        guard distance >= innerRadius, distance <= outerRadius + 30 else { return nil }
        var angle = atan2(offset.y, offset.x)
        if angle < 0 { angle += 2 * .pi }
        var relative = CGFloat.pi / 2 + slice / 2 - angle
        while relative < 0 { relative += 2 * .pi }
        while relative >= 2 * .pi { relative -= 2 * .pi }
        let rawIndex = Int(relative / slice)
        return min(count - 1, max(0, rawIndex))
    }
}

public struct WedgeShape: Shape {
    public var geometry: RadialGeometry
    public var index: Int

    public init(geometry: RadialGeometry, index: Int) {
        self.geometry = geometry
        self.index = index
    }

    public func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let (a0, a1) = geometry.angles(for: index)
        let r0 = geometry.innerRadius
        let r1 = geometry.outerRadius
        let k = geometry.corner
        let half = geometry.gap / 2
        let phiOuter = asin(min(0.9, (k + half) / max(r1 - k, 1)))
        let phiInner = asin(min(0.9, (k + half) / max(r0 + k, 1)))

        func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: c.x + cos(angle) * radius, y: c.y - sin(angle) * radius)
        }
        func normal(_ angle: CGFloat, inward: Bool) -> CGVector {
            inward ? CGVector(dx: sin(angle), dy: -cos(angle)) : CGVector(dx: -sin(angle), dy: cos(angle))
        }
        func offset(_ p: CGPoint, _ v: CGVector, _ distance: CGFloat) -> CGPoint {
            CGPoint(x: p.x + v.dx * distance, y: p.y - v.dy * distance)
        }
        func arc(_ path: inout Path, center: CGPoint, radius: CGFloat, from: CGPoint, to: CGPoint) {
            let s = atan2(from.y - center.y, from.x - center.x)
            let e = atan2(to.y - center.y, to.x - center.x)
            path.addArc(center: center, radius: radius, startAngle: .radians(s), endAngle: .radians(e), clockwise: true)
        }

        let outerEndCenter = point(r1 - k, a1 - phiOuter)
        let outerEndTangent = offset(outerEndCenter, normal(a1, inward: true), -k)
        let innerEndCenter = point(r0 + k, a1 - phiInner)
        let innerEndTangent = offset(innerEndCenter, normal(a1, inward: true), -k)
        let innerStartCenter = point(r0 + k, a0 + phiInner)
        let innerStartTangent = offset(innerStartCenter, normal(a0, inward: false), -k)
        let outerStartCenter = point(r1 - k, a0 + phiOuter)
        let outerStartTangent = offset(outerStartCenter, normal(a0, inward: false), -k)

        var path = Path()
        path.move(to: point(r1, a0 + phiOuter))
        path.addArc(center: c, radius: r1, startAngle: .radians(-(a0 + phiOuter)), endAngle: .radians(-(a1 - phiOuter)), clockwise: true)
        arc(&path, center: outerEndCenter, radius: k, from: point(r1, a1 - phiOuter), to: outerEndTangent)
        path.addLine(to: innerEndTangent)
        arc(&path, center: innerEndCenter, radius: k, from: innerEndTangent, to: point(r0, a1 - phiInner))
        path.addArc(center: c, radius: r0, startAngle: .radians(-(a1 - phiInner)), endAngle: .radians(-(a0 + phiInner)), clockwise: false)
        arc(&path, center: innerStartCenter, radius: k, from: point(r0, a0 + phiInner), to: innerStartTangent)
        path.addLine(to: outerStartTangent)
        arc(&path, center: outerStartCenter, radius: k, from: outerStartTangent, to: point(r1, a0 + phiOuter))
        path.closeSubpath()
        return path
    }
}
