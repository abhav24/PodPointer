import Foundation

/// Finds taps on the case: a short jolt of acceleration while the hand is steady.
public struct TapDetector: Sendable {
    public enum Event: Equatable, Sendable {
        case none
        /// A jolt began. It may still turn out to be a hand movement.
        case impulseStarted
        case tap
        case rejected
    }

    public var threshold: Double

    private static let stillRotationLimit = 0.9
    private static let stillWindowSeconds = 0.25
    private static let maximumImpulseSeconds = 0.16
    private static let afterTapSeconds = 0.12
    private static let afterRejectSeconds = 0.2
    private static let resetGapSeconds = 0.5

    private var previousAcceleration: Vector3?
    private var previousTime = -Double.infinity
    private var impulseStart: Double?
    private var ignoreUntil = -Double.infinity
    private var recentRotation: [(time: Double, speed: Double)] = []

    public init(threshold: Double) {
        self.threshold = threshold
    }

    public mutating func process(acceleration: Vector3, rotationSpeed: Double, at time: Double) -> Event {
        defer {
            previousAcceleration = acceleration
            previousTime = time
        }
        guard let previous = previousAcceleration, time - previousTime < Self.resetGapSeconds else {
            impulseStart = nil
            recentRotation.removeAll()
            return .none
        }
        let impulse = (acceleration - previous).magnitude

        if let start = impulseStart {
            if impulse < threshold * 0.5 {
                impulseStart = nil
                ignoreUntil = time + Self.afterTapSeconds
                return .tap
            }
            if time - start > Self.maximumImpulseSeconds {
                impulseStart = nil
                ignoreUntil = time + Self.afterRejectSeconds
                return .rejected
            }
            return .none
        }

