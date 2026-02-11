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
