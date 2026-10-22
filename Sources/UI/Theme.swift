import AppKit
import SwiftUI

enum Theme {
    static var accentNS: NSColor {
        switch AppSettings.shared.accentTheme {
        case .pastelIndigo:
            return NSColor(srgbRed: 0.44, green: 0.48, blue: 0.96, alpha: 1.0)
        case .pastelMint:
            return NSColor(srgbRed: 0.28, green: 0.80, blue: 0.65, alpha: 1.0)
        case .pastelRose:
            return NSColor(srgbRed: 0.94, green: 0.45, blue: 0.58, alpha: 1.0)
        case .system:
            return NSColor.controlAccentColor
        }
    }

    static var accent: Color {
        Color(nsColor: accentNS)
    }

    static let ink = Color(nsColor: .labelColor)
    static let inkSecondary = Color(nsColor: .secondaryLabelColor)
    static let cardCorner: CGFloat = 12

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = Theme.cardCorner

    func body(content: Content) -> some View {
        content
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            }
    }
}

extension View {
    func card(cornerRadius: CGFloat = Theme.cardCorner) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

struct SegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}


/// A brief, state-driven illustration: no permanent animation timer.
struct SettingsPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwipState private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(hovering ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 13))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: hovering)
            .onHover { hovering = $0 }
    }
}
