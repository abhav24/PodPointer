import AppKit
import PodPointerCore
import QuartzCore

/// A red dot in a transparent, click-through window above the slides.
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

        dot.frame = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)
        dot.cornerRadius = Self.dotSize / 2
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.shadowColor = NSColor.systemRed.cgColor
