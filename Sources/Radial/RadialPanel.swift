import AppKit

public final class RadialPanel: NSPanel {
    public let radialView = RadialView(frame: .zero)

    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        radialView.frame = contentView?.bounds ?? .zero
        radialView.autoresizingMask = [.width, .height]
        contentView = radialView
    }

    public override var canBecomeKey: Bool { true }
}
