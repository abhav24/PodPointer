import Foundation

public struct CaseOutput: Equatable, Sendable {
    public var point: PointerPoint
    public var gesture: CaseGesture?
    /// True on the sample where a tap began.
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
    private static let holdAfterTapSeconds = 0.15
    private static let degreesPerRadian = 180 / Double.pi

    private var engine: PointerEngine
    private var detector: TapDetector
    private var sequence = TapSequence()
    private var holdUntil = -Double.infinity

    public init(calibration: CaseCalibration, pointerConfiguration: PointerConfiguration = PointerConfiguration()) {
        self.calibration = calibration
        engine = PointerEngine(configuration: pointerConfiguration)
        detector = TapDetector(threshold: Self.detectionThreshold(for: calibration))
    }

    private static func detectionThreshold(for calibration: CaseCalibration) -> Double {
        calibration.tapThreshold * thresholdMargin
    }

    public mutating func process(_ reading: MotionReading) -> CaseOutput {
        let time = reading.timestamp
        let rotation = reading.rotationRate - calibration.gyroBias
        var gesture: CaseGesture?

        let tapped = detector.process(
            acceleration: reading.userAcceleration,
            rotationSpeed: rotation.magnitude,
            at: time
        )
        if tapped {
            // A tap also shakes the pointer, so undo that and hold it in place.
            engine.rollBack(from: time)
            holdUntil = time + Self.holdAfterTapSeconds
            gesture = sequence.registerTap(at: time)
        case .rejected:
            isHolding = false
        }
        if isHolding, time >= holdUntil {
            isHolding = false
        }
        gesture = gesture ?? sequence.poll(at: time)

        let point: PointerPoint
        if isHolding {
            point = engine.hold(at: time)
        } else {
            point = engine.advance(
                horizontalRate: rotation.dot(calibration.horizontalAxis) * Self.degreesPerRadian,
                verticalRate: rotation.dot(calibration.verticalAxis) * Self.degreesPerRadian,
                at: time
            )
        }
        return CaseOutput(point: point, gesture: gesture)
    }

    public mutating func setPosition(_ point: PointerPoint) {
        engine.set(position: point)
    }
}
