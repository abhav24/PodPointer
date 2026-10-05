import Foundation

public struct CaseOutput: Equatable, Sendable {
    public var point: PointerPoint
    /// Set once a tap group ends and the case has settled.
    public var gesture: CaseGesture?
    /// How long ago the gesture's last tap happened.
    public var gestureAge: Double
    /// True on the sample where a tap is confirmed. A gesture can still be
    /// dropped later if the case keeps shaking.
    public var tapped: Bool
}

/// Combines calibration, tap detection, and pointer movement into one input.
public struct CaseInputProcessor: Sendable {
    public let calibration: CaseCalibration

    public var pointerConfiguration: PointerConfiguration {
        get { engine.configuration }
        set { engine.configuration = newValue }
    }

    /// Above 1 makes lighter taps count. Below 1 needs firmer taps.
    public var tapSensitivity = 1.0 {
        didSet { detector.threshold = Self.detectionThreshold(for: calibration) / tapSensitivity }
    }

    /// How long to wait for another tap before acting on a tap group.
    public var multiTapWindow: Double {
        get { sequence.windowSeconds }
        set { sequence.windowSeconds = newValue }
    }

    /// Asks for slightly firmer taps than calibration measured, which removes
    /// weak false taps without losing real ones.
    private static let thresholdMargin = 1.1
    /// Below this, tiny movements of the hand look like taps.
    private static let minimumThreshold = 0.12
    /// Hard taps during calibration shouldn't make everyday taps stop counting.
    /// Movement is rejected by a tap's shape, so a high threshold isn't needed.
    private static let maximumThreshold = 0.17
    /// How long the pointer stays put after a tap begins.
    private static let holdAfterTapSeconds = 0.2
    /// The first part of a tap's own shake doesn't count as still shaking.
    private static let settleCheckDelay = 0.2
    private static let degreesPerRadian = 180 / Double.pi

    private struct HeldMotion {
        let horizontalRate: Double
        let verticalRate: Double
        let time: Double
    }

    private var engine: PointerEngine
    private var detector: TapDetector
    private var sequence = TapSequence()
    private var holdUntil = -Double.infinity
    private var heldMotion: [HeldMotion] = []

    public init(calibration: CaseCalibration, pointerConfiguration: PointerConfiguration = PointerConfiguration()) {
        self.calibration = calibration
        engine = PointerEngine(configuration: pointerConfiguration)
        detector = TapDetector(threshold: Self.detectionThreshold(for: calibration))
    }

    private static func detectionThreshold(for calibration: CaseCalibration) -> Double {
        min(max(calibration.tapThreshold * thresholdMargin, minimumThreshold), maximumThreshold)
    }

    public mutating func process(_ reading: MotionReading) -> CaseOutput {
        let time = reading.timestamp
        let rotation = reading.rotationRate - calibration.gyroBias

        let tap = detector.process(acceleration: reading.userAcceleration, rotation: rotation, at: time)
        if let tap {
            // A tap also shakes the pointer, so undo that and hold it in place.
            heldMotion.removeAll()
            engine.rollBack(from: tap.time)
            holdUntil = tap.time + Self.holdAfterTapSeconds
            sequence.registerTap(at: tap.time)
        }

        let lastTap = sequence.lastTap
        var gesture: CaseGesture?
        if !detector.isChecking, let finished = sequence.poll(at: time),
           detector.hasSettled(since: lastTap + Self.settleCheckDelay) {
            gesture = finished
        }

        let point = advancePointer(
            horizontalRate: rotation.dot(calibration.horizontalAxis) * Self.degreesPerRadian,
            verticalRate: rotation.dot(calibration.verticalAxis) * Self.degreesPerRadian,
            at: time
        )
        return CaseOutput(
            point: point,
            gesture: gesture,
            gestureAge: gesture == nil ? 0 : time - lastTap,
            tapped: tap != nil
        )
    }

    public mutating func setPosition(_ point: PointerPoint) {
        engine.set(position: point)
    }
}
