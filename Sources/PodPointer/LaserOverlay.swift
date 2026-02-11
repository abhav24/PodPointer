import AppKit
import PodPointerCore
import QuartzCore

/// A red dot in a transparent, click-through window above the slides.
final class LaserOverlay {
    private static let dotSize: CGFloat = 22

    private let panel: NSPanel
    private let dot = CALayer()

