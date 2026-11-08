import Foundation

public struct CaseOutput: Equatable, Sendable {
    public var point: PointerPoint
    public var gesture: CaseGesture?
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
        didSet { detector.threshold = calibration.tapThreshold / tapSensitivity }
    }

    private static let settleSeconds = 0.08
    private static let degreesPerRadian = 180 / Double.pi

    private var engine: PointerEngine
    private var detector: TapDetector
    private var sequence = TapSequence()
    private var isHolding = false
    private var holdUntil = Double.infinity

    public init(calibration: CaseCalibration, pointerConfiguration: PointerConfiguration = PointerConfiguration()) {
        self.calibration = calibration
        engine = PointerEngine(configuration: pointerConfiguration)
        detector = TapDetector(threshold: calibration.tapThreshold)
    }

    public mutating func process(_ reading: MotionReading) -> CaseOutput {
        let time = reading.timestamp
        let rotation = reading.rotationRate - calibration.gyroBias
        var gesture: CaseGesture?

        switch detector.process(acceleration: reading.userAcceleration, rotationSpeed: rotation.magnitude, at: time) {
        case .none:
            break
        case .impulseStarted:
            engine.rollBack(from: time)
            isHolding = true
            holdUntil = .infinity
        case .tap:
            holdUntil = time + Self.settleSeconds
            gesture = sequence.registerTap(at: time)
        case .rejected:
            isHolding = false
        }
        if isHolding, time >= holdUntil {
            isHolding = false
        }
        gesture = gesture ?? sequence.poll(at: time)

