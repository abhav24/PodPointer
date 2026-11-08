import Foundation

/// Finds taps on the case from sudden changes in acceleration.
///
/// A tap leaves the case shaking for a moment, so the detector follows that
/// shake as it fades. A later jolt only counts if it clearly stands out from
/// what's left of the shake, which lets quick double and triple taps through.
public struct TapDetector: Sendable {
    public var threshold: Double

    /// How fast the shake from a tap is assumed to fade, in seconds.
    private static let shakeFadeSeconds = 0.06
    /// How far a jolt must stand out from the remaining shake.
    private static let aboveShakeRatio = 2.0
    /// How far a jolt must stand out from recent movement.
    private static let aboveMovementRatio = 2.0
    /// The AirPods bounce inside the case, so one tap can show up as two jolts
    /// up to about 100 ms apart. Closer jolts than this are the same tap.
    private static let minimumTapSpacing = 0.14
    private static let movementWindowSeconds = 0.3
    /// Movement right after a tap is shake from the tap, not the hand moving.
    private static let afterTapSettleSeconds = 0.25
    /// Fast rotation means the hand is moving, so a jolt probably isn't a tap.
    private static let movingRotationLimit = 1.5
    private static let rotationWindowSeconds = 0.25
    /// Within a tap group, the shake from earlier taps is expected.
    private static let tapGroupSeconds = 0.7
    private static let longestTapGroup = 3
    private static let resetGapSeconds = 0.5

    private var previousAcceleration: Vector3?
    private var previousTime = -Double.infinity
    private var shake = 0.0
    private var lastTapTime = -Double.infinity
    private var tapsInGroup = 0
    private var recentJolts: [(time: Double, jolt: Double)] = []
    private var recentRotation: [(time: Double, speed: Double)] = []

    public init(threshold: Double) {
        self.threshold = threshold
    }

    /// Returns true on the sample where a tap begins.
    public mutating func process(acceleration: Vector3, rotationSpeed: Double, at time: Double) -> Bool {
        defer {
            previousAcceleration = acceleration
            previousTime = time
        }
        guard let previous = previousAcceleration, time - previousTime < Self.resetGapSeconds else {
            shake = 0
            recentJolts.removeAll()
            recentRotation.removeAll()
            return false
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
