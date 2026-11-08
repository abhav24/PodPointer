import Foundation

/// A position on a display, normalized to 0...1. (0, 0) is the top-left corner.
public struct PointerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PointerConfiguration: Equatable, Sendable {
    /// Degrees of head turn that cover the full width of the display.
    public var horizontalRangeDegrees = 30.0
    /// Degrees of head tilt that cover the full height of the display.
    public var verticalRangeDegrees = 20.0
    public var invertX = false
    public var invertY = false
    /// Lower values are steadier but lag more when the head moves slowly.
    public var minCutoff = 1.0
    /// Higher values reduce lag during fast head movement.
    public var beta = 0.05

    public init() {}
}

/// Maps head orientation to a display position. The orientation at recenter
/// time is the middle of the display.
public struct PointerMapper: Sendable {
    public var configuration: PointerConfiguration {
        didSet { applyFilterConfiguration() }
    }

    private var centerYaw: Double?
    private var centerPitch = 0.0
    private var xFilter = OneEuroFilter()
    private var yFilter = OneEuroFilter()

    public init(configuration: PointerConfiguration = PointerConfiguration()) {
        self.configuration = configuration
        applyFilterConfiguration()
    }

    /// Makes the next sample the new center of the display.
    public mutating func recenter() {
        centerYaw = nil
        xFilter.reset()
        yFilter.reset()
    }

