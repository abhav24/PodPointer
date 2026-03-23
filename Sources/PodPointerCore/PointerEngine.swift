import Foundation

/// A position on a display, from 0 to 1. (0, 0) is the top-left corner.
public struct PointerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public static let center = PointerPoint(x: 0.5, y: 0.5)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Moves part of the way to a target, independent of the frame rate.
    public func eased(toward target: PointerPoint, elapsed: Double, timeConstant: Double) -> PointerPoint {
        let alpha = 1 - exp(-max(elapsed, 0) / timeConstant)
        return PointerPoint(x: x + (target.x - x) * alpha, y: y + (target.y - y) * alpha)
    }
}

public struct PointerConfiguration: Equatable, Sendable {
    /// Degrees of rotation that move the pointer across the full display width.
    public var rangeDegrees = 40.0
    public var aspectRatio = 16.0 / 10.0
    /// Slower rotation than this is treated as hand tremor.
    public var deadZoneDegreesPerSecond = 2.0
    /// How much fast movements are sped up. 1 means no speed-up.
    public var maximumAcceleration = 1.6
    /// Lower values are steadier but lag more.
    public var minCutoff = 1.5
    public var beta = 0.02

    public init() {}
}

/// Turns rotation speed into a pointer position, the way a mouse turns movement
/// into cursor travel. Reaching a display edge also resets where you're aiming.
public struct PointerEngine: Sendable {
    public var configuration: PointerConfiguration {
        didSet { applyFilterSettings() }
    }
    public private(set) var position = PointerPoint.center

    private static let maximumStepSeconds = 0.1
    private static let historySeconds = 0.4
    private static let rollbackSeconds = 0.08

