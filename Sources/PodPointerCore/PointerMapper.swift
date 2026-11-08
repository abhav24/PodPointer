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

    public mutating func map(yawRadians: Double, pitchRadians: Double, at time: Double) -> PointerPoint {
        if centerYaw == nil {
            centerYaw = yawRadians
            centerPitch = pitchRadians
        }
        let yawDegrees = Self.degrees(Self.wrapped(yawRadians - (centerYaw ?? yawRadians)))
        let pitchDegrees = Self.degrees(Self.wrapped(pitchRadians - centerPitch))

        // Core Motion yaw increases when turning left, and pitch increases when
        // looking up. Screen x grows to the right, and y grows downward.
        let xDirection = configuration.invertX ? 1.0 : -1.0
        let yDirection = configuration.invertY ? 1.0 : -1.0
        let rawX = 0.5 + xDirection * yawDegrees / configuration.horizontalRangeDegrees
        let rawY = 0.5 + yDirection * pitchDegrees / configuration.verticalRangeDegrees

        return PointerPoint(
            x: Self.clamped(xFilter.filter(rawX * configuration.horizontalRangeDegrees, at: time) / configuration.horizontalRangeDegrees),
            y: Self.clamped(yFilter.filter(rawY * configuration.verticalRangeDegrees, at: time) / configuration.verticalRangeDegrees)
        )
    }

    private mutating func applyFilterConfiguration() {
        xFilter.minCutoff = configuration.minCutoff
        xFilter.beta = configuration.beta
        yFilter.minCutoff = configuration.minCutoff
        yFilter.beta = configuration.beta
    }

    /// Wraps an angle to -pi...pi so crossing the +/-180 degree seam is not a jump.
    private static func wrapped(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
