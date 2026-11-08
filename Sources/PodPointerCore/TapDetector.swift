import Foundation

/// A tap that passed every check.
public struct DetectedTap: Equatable, Sendable {
    /// When the tap began, a little before it was confirmed.
    public var time: Double
    /// The largest change in acceleration between samples, in g.
    public var strength: Double
}

/// Finds taps on the case from sudden changes in acceleration.
///
/// Moving the case can cause jolts as large as a tap, so size alone can't tell
/// them apart. A jolt counts as a tap only if the case was calm before it, and
/// then barely turned and only briefly shook. The detector waits a moment after
/// each jolt to check this, so a tap is reported slightly after it began.
///
/// A tap also leaves the case shaking, so the detector follows that shake as it
/// fades. A later jolt must stand out from what's left of it, which lets quick
/// double and triple taps through.
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

        let jolt = (acceleration - previous).magnitude
        shake *= exp(-(time - previousTime) / Self.shakeFadeSeconds)
        recentJolts.removeAll { time - $0.time > Self.movementWindowSeconds }
        recentRotation.removeAll { time - $0.time > Self.rotationWindowSeconds }

        // Triple is the longest gesture, so a fourth tap gets the normal checks.
        // Otherwise, one false tap while moving could set off a chain of them.
        let isInTapGroup = time - lastTapTime < Self.tapGroupSeconds && tapsInGroup < Self.longestTapGroup
        let isTap = jolt >= threshold
            && time - lastTapTime >= Self.minimumTapSpacing
            && jolt >= shake * Self.aboveShakeRatio
            && (isInTapGroup || (jolt >= recentMovement * Self.aboveMovementRatio && isSteady))

        if isTap {
            tapsInGroup = time - lastTapTime < Self.tapGroupSeconds ? tapsInGroup + 1 : 1
            lastTapTime = time
        }
        shake = max(shake, jolt)

        let hasSettled = time - lastTapTime >= Self.afterTapSettleSeconds
        if hasSettled {
            recentJolts.append((time, jolt))
        }
        if hasSettled || tapsInGroup >= Self.longestTapGroup {
            recentRotation.append((time, rotationSpeed))
        }
        return isTap
    }

    private var recentMovement: Double {
        guard !recentJolts.isEmpty else { return 0 }
        return recentJolts.reduce(0) { $0 + $1.jolt } / Double(recentJolts.count)
    }

    private var isSteady: Bool {
        recentRotation.allSatisfy { $0.speed < Self.movingRotationLimit }
    }
}

public enum CaseGesture: String, CaseIterable, Sendable {
    case single
    case double
    case triple
}

/// Groups taps into single, double, and triple taps.
public struct TapSequence: Sendable {
    /// How long to wait for another tap. A single tap acts after this delay.
    public var windowSeconds: Double
    private var count = 0
    private var lastTap = -Double.infinity

    public init(windowSeconds: Double = 0.4) {
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
