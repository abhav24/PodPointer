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

    /// How long to watch a jolt before calling it a tap. No longer than
    /// `minimumTapSpacing`, so the next tap in a group is never missed.
    private static let confirmSeconds = 0.14
    /// A tap barely turns the case. Moving it turns it much faster and further.
    private static let tapRotationLimit = 3.3
    private static let tapTurnLimitRadians = 9 * Double.pi / 180
    /// In g. Above this, the case is being swung, not tapped.
    private static let tapAccelerationLimit = 2.0
    /// A tap's jolt is about as large as its acceleration. When the hand moves
    /// the case, acceleration builds up over many samples instead.
    private static let minimumSharpness = 0.55
    private static let peakJoltSeconds = 0.1

    /// How fast the shake from a tap is assumed to fade, in seconds.
    private static let shakeFadeSeconds = 0.06
    /// How far a jolt must stand out from the remaining shake.
    private static let aboveShakeRatio = 2.0
    /// How far a jolt must stand out from recent movement.
    private static let aboveMovementRatio = 2.0
    /// The AirPods bounce inside the case, so one tap can show up as two jolts
    /// up to about 100 ms apart. Closer jolts than this are the same tap.
    private static let minimumTapSpacing = 0.14
    /// A jolt soon after a tap and much weaker than it is the same tap bouncing.
    private static let bounceSeconds = 0.25
    private static let bounceStrengthRatio = 0.4
    /// Motion right after a tap is shake from the tap, not the hand moving.
    private static let afterTapSettleSeconds = 0.25
    private static let calmWindowSeconds = 0.25
    /// Too little history can't show that the case was calm.
    private static let minimumCalmSeconds = 0.2
    /// The first samples of a tap can come before the jolt crosses the threshold.
    private static let onsetSeconds = 0.04
    private static let calmRotationLimit = 2.0
    private static let calmAccelerationLimit = 0.15
    /// As a share of the threshold. Any repeating motion strong enough to reach
    /// the threshold averages about 0.64 of it, so it fails this check.
    private static let calmJoltRatio = 0.5
    /// Within a tap group, the shake from earlier taps is expected.
    private static let tapGroupSeconds = 0.7
    private static let longestTapGroup = 3
    private static let resetGapSeconds = 0.5
    private static let joltHistorySeconds = 0.5

    private struct Candidate {
        let time: Double
        var turn: Vector3
        var peakRotation: Double
        var peakAcceleration: Double
        var peakJolt: Double
    }

    private struct CalmSample {
        let time: Double
        let jolt: Double
        let acceleration: Double
        let rotation: Double
    }

    private var previousAcceleration: Vector3?
    private var previousTime = -Double.infinity
    private var shake = 0.0
    private var lastTapTime = -Double.infinity
    private var lastTapStrength = 0.0
    private var tapsInGroup = 0
    private var candidate: Candidate?
    private var calmSamples: [CalmSample] = []
    private var jolts: [(time: Double, jolt: Double)] = []

    public init(threshold: Double) {
        self.threshold = threshold
    }

    /// True while a jolt is being checked. The pointer should wait for the result.
    public var isChecking: Bool { candidate != nil }

    /// Returns a tap on the sample where it's confirmed.
    public mutating func process(acceleration: Vector3, rotation: Vector3, at time: Double) -> DetectedTap? {
        defer {
            previousAcceleration = acceleration
            previousTime = time
        }
        guard let previous = previousAcceleration, time - previousTime < Self.resetGapSeconds else {
            shake = 0
            candidate = nil
            calmSamples.removeAll()
            jolts.removeAll()
            return nil
        }

        let jolt = (acceleration - previous).magnitude
        let elapsed = time - previousTime
        let rotationSpeed = rotation.magnitude
        let accelerationSize = acceleration.magnitude
        shake *= exp(-elapsed / Self.shakeFadeSeconds)
        jolts.removeAll { time - $0.time > Self.joltHistorySeconds }
        jolts.append((time, jolt))
        calmSamples.removeAll { time - $0.time > Self.calmWindowSeconds }

        let tap = checkCandidate(
            jolt: jolt,
            rotation: rotation,
            rotationSpeed: rotationSpeed,
            accelerationSize: accelerationSize,
            elapsed: elapsed,
            at: time
        )

        if candidate == nil, joltCouldBeTap(jolt, at: time) {
            candidate = Candidate(
                time: time,
                turn: rotation * elapsed,
                peakRotation: rotationSpeed,
                peakAcceleration: accelerationSize,
                peakJolt: jolt
            )
        }
        shake = max(shake, jolt)

        let hasSettled = candidate == nil && time - lastTapTime >= Self.afterTapSettleSeconds
        if hasSettled || tapsInGroup >= Self.longestTapGroup {
            calmSamples.append(CalmSample(time: time, jolt: jolt, acceleration: accelerationSize, rotation: rotationSpeed))
        }
        return tap
    }

    /// False if the case kept jolting since `time`, which means it's being shaken.
    public func hasSettled(since time: Double) -> Bool {
        let recent = jolts.filter { $0.time >= time }
        guard !recent.isEmpty else { return true }
        let average = recent.reduce(0) { $0 + $1.jolt } / Double(recent.count)
        return average <= threshold * Self.calmJoltRatio
    }

    private mutating func checkCandidate(
        jolt: Double,
        rotation: Vector3,
        rotationSpeed: Double,
        accelerationSize: Double,
        elapsed: Double,
        at time: Double
    ) -> DetectedTap? {
        guard var current = candidate else { return nil }
        current.turn = current.turn + rotation * elapsed
        current.peakRotation = max(current.peakRotation, rotationSpeed)
        current.peakAcceleration = max(current.peakAcceleration, accelerationSize)
        if time - current.time <= Self.peakJoltSeconds {
            current.peakJolt = max(current.peakJolt, jolt)
        }

        // Most movement fails within a few samples, so the pointer barely waits.
        guard current.peakRotation <= Self.tapRotationLimit,
              current.peakAcceleration <= Self.tapAccelerationLimit,
              current.turn.magnitude <= Self.tapTurnLimitRadians else {
            candidate = nil
            return nil
        }
        guard time - current.time >= Self.confirmSeconds else {
            candidate = current
            return nil
        }

        candidate = nil
        guard current.peakJolt >= current.peakAcceleration * Self.minimumSharpness else { return nil }
        let isBounce = current.time - lastTapTime < Self.bounceSeconds
            && current.peakJolt < lastTapStrength * Self.bounceStrengthRatio
        guard !isBounce else { return nil }
        tapsInGroup = current.time - lastTapTime < Self.tapGroupSeconds ? tapsInGroup + 1 : 1
        lastTapTime = current.time
        lastTapStrength = current.peakJolt
        return DetectedTap(time: current.time, strength: current.peakJolt)
    }

    private func joltCouldBeTap(_ jolt: Double, at time: Double) -> Bool {
        guard jolt >= threshold,
              time - lastTapTime >= Self.minimumTapSpacing,
              jolt >= shake * Self.aboveShakeRatio else { return false }
        // Triple is the longest gesture, so a fourth tap gets the normal checks.
        // Otherwise, one false tap while moving could set off a chain of them.
        let isInTapGroup = time - lastTapTime < Self.tapGroupSeconds && tapsInGroup < Self.longestTapGroup
        return isInTapGroup || isCalm(before: jolt, at: time)
    }

    private func isCalm(before jolt: Double, at time: Double) -> Bool {
        guard let oldest = calmSamples.first, time - oldest.time >= Self.minimumCalmSeconds else { return false }
        let movement = average(calmSamples.map(\.jolt))
        let beforeOnset = calmSamples.filter { time - $0.time >= Self.onsetSeconds }
        return jolt >= movement * Self.aboveMovementRatio
            && calmSamples.allSatisfy { $0.rotation < Self.calmRotationLimit }
            && average(beforeOnset.map(\.acceleration)) <= Self.calmAccelerationLimit
            && average(beforeOnset.map(\.jolt)) <= threshold * Self.calmJoltRatio
    }

    private func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

public enum CaseGesture: String, CaseIterable, Sendable {
    case single
    case double
    case triple

    public var tapCount: Int {
        switch self {
        case .single: return 1
        case .double: return 2
        case .triple: return 3
        }
    }
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
