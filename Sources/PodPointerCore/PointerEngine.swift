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
    public var invertHorizontal = false
    public var invertVertical = false
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

    private var rawPosition = PointerPoint.center
    private var xFilter = OneEuroFilter(minCutoff: 1, beta: 0)
    private var yFilter = OneEuroFilter(minCutoff: 1, beta: 0)
    private var lastTime: Double?
    private var history: [(time: Double, point: PointerPoint)] = []

    public init(configuration: PointerConfiguration = PointerConfiguration()) {
        self.configuration = configuration
        applyFilterSettings()
    }

    /// Rates are in degrees per second. Positive is right and up.
    public mutating func advance(horizontalRate: Double, verticalRate: Double, at time: Double) -> PointerPoint {
        defer { lastTime = time }
        guard let last = lastTime else { return position }
        let elapsed = time - last
        guard elapsed > 0, elapsed <= Self.maximumStepSeconds else { return position }

        let horizontal = applyDeadZone(horizontalRate) * (configuration.invertHorizontal ? -1 : 1)
        let vertical = applyDeadZone(verticalRate) * (configuration.invertVertical ? -1 : 1)
        let speed = (horizontal * horizontal + vertical * vertical).squareRoot()
        let boost = 1 + (configuration.maximumAcceleration - 1) * min(speed / 90, 1)

        let widthDegrees = configuration.rangeDegrees
        let heightDegrees = widthDegrees / configuration.aspectRatio
        rawPosition.x = Self.clamped(rawPosition.x + horizontal * boost * elapsed / widthDegrees)
        rawPosition.y = Self.clamped(rawPosition.y - vertical * boost * elapsed / heightDegrees)

        history.append((time, rawPosition))
        history.removeAll { time - $0.time > Self.historySeconds }

        // Filtering in degrees makes the filter's speed setting independent of the range.
        position = PointerPoint(
            x: Self.clamped(xFilter.filter(rawPosition.x * widthDegrees, at: time) / widthDegrees),
            y: Self.clamped(yFilter.filter(rawPosition.y * heightDegrees, at: time) / heightDegrees)
        )
        return position
    }

    /// Keeps the pointer in place, for use while a tap is shaking the case.
    public mutating func hold(at time: Double) -> PointerPoint {
        lastTime = time
        return position
    }

    /// Undoes the movement just before a tap, because the jolt starts before it's detected.
    public mutating func rollBack(from time: Double) {
        guard let earlier = history.last(where: { time - $0.time >= Self.rollbackSeconds }) else { return }
        set(position: earlier.point)
    }

    public mutating func set(position point: PointerPoint) {
        rawPosition = PointerPoint(x: Self.clamped(point.x), y: Self.clamped(point.y))
        position = rawPosition
        xFilter.reset()
        yFilter.reset()
        history.removeAll()
    }

    private func applyDeadZone(_ rate: Double) -> Double {
        let zone = configuration.deadZoneDegreesPerSecond
        guard abs(rate) > zone else { return 0 }
        return rate > 0 ? rate - zone : rate + zone
    }

    private mutating func applyFilterSettings() {
        xFilter.minCutoff = configuration.minCutoff
        xFilter.beta = configuration.beta
        yFilter.minCutoff = configuration.minCutoff
        yFilter.beta = configuration.beta
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
