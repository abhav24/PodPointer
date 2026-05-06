import AppKit
import PodPointerCore
import QuartzCore

/// A red dot in a transparent, click-through window above everything else.
final class LaserOverlay {
    private static let dotSize: CGFloat = 22

    private let panel: NSPanel
    private let dot = CALayer()

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = NSView()
        view.wantsLayer = true
        panel.contentView = view

        dot.bounds = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)
        dot.cornerRadius = Self.dotSize / 2
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.shadowColor = NSColor.systemRed.cgColor
        dot.shadowOpacity = 0.9
        dot.shadowRadius = 12
        dot.shadowOffset = .zero
        view.layer?.addSublayer(dot)
    }

    func show(on screen: NSScreen) {
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func move(to point: PointerPoint) {
        let size = panel.frame.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Layers put the origin at the bottom left, and PointerPoint at the top left.
        dot.position = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
        CATransaction.commit()
    }
}
