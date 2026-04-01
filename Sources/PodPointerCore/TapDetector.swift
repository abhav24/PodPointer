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

        guard time >= ignoreUntil else { return .none }
        if impulse >= threshold, isHandStill(at: time) {
            impulseStart = time
            return .impulseStarted
        }
        // A tap jolts the gyroscope too, so samples during and after a tap
        // aren't recorded. Otherwise the second tap of a double tap would fail.
        recentRotation.append((time, rotationSpeed))
        return .none
    }

    private mutating func isHandStill(at time: Double) -> Bool {
        recentRotation.removeAll { time - $0.time > Self.stillWindowSeconds }
        return recentRotation.allSatisfy { $0.speed < Self.stillRotationLimit }
    }
}

public enum CaseGesture: String, CaseIterable, Sendable {
    case single
    case double
    case triple
}

/// Groups taps into single, double, and triple taps.
public struct TapSequence: Sendable {
    public let windowSeconds: Double
    private var count = 0
    private var lastTap = -Double.infinity

    public init(windowSeconds: Double = 0.35) {
        self.windowSeconds = windowSeconds
    }

    /// Returns a gesture right away on the third tap, since no longer gesture exists.
    public mutating func registerTap(at time: Double) -> CaseGesture? {
        count += 1
        lastTap = time
        guard count >= 3 else { return nil }
        count = 0
        return .triple
    }

    /// Returns a gesture once enough time has passed with no further tap.
    public mutating func poll(at time: Double) -> CaseGesture? {
        guard count > 0, time - lastTap >= windowSeconds else { return nil }
        defer { count = 0 }
        return count == 1 ? .single : .double
    }
}
