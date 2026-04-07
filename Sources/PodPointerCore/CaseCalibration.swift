import Foundation

/// What calibration learns about one way of holding the case.
///
/// The AirPods sit at an arbitrary angle in your hand, so the sensor's axes
/// don't line up with the screen. Calibration finds which rotation means
/// "right" and which means "up", then measures how hard your taps are.
public struct CaseCalibration: Codable, Equatable, Sendable {
    /// Unit axis. Positive rotation around it moves the pointer right.
    public var horizontalAxis: Vector3
    /// Unit axis. Positive rotation around it moves the pointer up.
    public var verticalAxis: Vector3
    /// The gyroscope's reading at rest, in radians per second.
    public var gyroBias: Vector3
    /// The change in acceleration between samples that counts as a tap, in g.
    public var tapThreshold: Double
    /// Which AirPod was sending motion. The other one sits at a different angle.
    public var sensorLocation: String

    public init(
        horizontalAxis: Vector3,
        verticalAxis: Vector3,
        gyroBias: Vector3,
        tapThreshold: Double,
        sensorLocation: String
    ) {
        self.horizontalAxis = horizontalAxis
        self.verticalAxis = verticalAxis
        self.gyroBias = gyroBias
        self.tapThreshold = tapThreshold
        self.sensorLocation = sensorLocation
    }
}

public enum CalibrationStep: Equatable, Sendable {
    case holdStill
    case sweepSideways
    case sweepVertically
    case tap
}

public enum CalibrationFailure: String, Error, Equatable, Sendable {
    case tooFewSamples = "Motion samples arrived too slowly. Check the connection and try again."
    case tooLittleMovement = "There wasn't enough movement. Sweep the case further and try again."
    case unclearMovement = "The movement was hard to read. Keep each sweep in one direction and try again."
    case axesTooSimilar = "The two sweeps looked the same. Sweep sideways, then up and down, and try again."
    case tooFewTaps = "Too few taps were detected. Tap the case more firmly and try again."
    case tapsTooWeak = "The taps were hard to tell apart from noise. Tap more firmly and try again."
}

public enum CalibrationStatus: Equatable, Sendable {
    case inProgress
    case finished(CaseCalibration)
    case failed(CalibrationFailure)
}

/// Runs calibration from motion samples alone, so it can be tested without hardware.
public struct CalibrationSession: Sendable {
    public static let requiredTaps = 5

    private static let holdSeconds = 2.0
    private static let sweepSeconds = 4.0
    private static let tapTimeoutSeconds = 10.0
    private static let minimumHoldSamples = 20
    private static let minimumSweepSamples = 12
    private static let minimumTaps = 3
    private static let holdMotionLimit = 0.5
    private static let sweepMotionFloor = 0.35
    private static let minimumAxisEnergy = 0.6
    private static let minimumAxisSeparation = 0.5
    private static let tapPeakSeconds = 0.15
    private static let tapSpacingSeconds = 0.25

    public private(set) var step = CalibrationStep.holdStill
    public private(set) var progress = 0.0
    public private(set) var tapsFound = 0

    private let sensorLocation: String
    private var stepStart: Double?
    private var previousAcceleration: Vector3?

    private var restingSum = Vector3.zero
    private var restingCount = 0
    private var noiseFloor = 0.0
    private var gyroBias = Vector3.zero

    private var sweepSamples: [Vector3] = []
    private var horizontalAxis = Vector3.zero
    private var verticalAxis = Vector3.zero

    private var tapPeaks: [Double] = []
    private var currentPeak: Double?
    private var currentPeakStart = -Double.infinity

    public init(sensorLocation: String) {
        self.sensorLocation = sensorLocation
    }

    public mutating func process(_ reading: MotionReading) -> CalibrationStatus {
        let start = stepStart ?? reading.timestamp
        stepStart = start
        let elapsed = reading.timestamp - start
        let impulse = previousAcceleration.map { (reading.userAcceleration - $0).magnitude } ?? 0
        previousAcceleration = reading.userAcceleration

        switch step {
        case .holdStill:
            return processHold(reading, impulse: impulse, elapsed: elapsed)
        case .sweepSideways, .sweepVertically:
            return processSweep(reading, elapsed: elapsed)
        case .tap:
            return processTap(impulse: impulse, time: reading.timestamp, elapsed: elapsed)
        }
    }

    private mutating func processHold(_ reading: MotionReading, impulse: Double, elapsed: Double) -> CalibrationStatus {
        if reading.rotationRate.magnitude > Self.holdMotionLimit {
            // The case moved, so measure the resting values again.
            restingSum = .zero
            restingCount = 0
            noiseFloor = 0
            stepStart = reading.timestamp
            progress = 0
            return .inProgress
        }
        restingSum = restingSum + reading.rotationRate
        restingCount += 1
        noiseFloor = max(noiseFloor, impulse)
        progress = min(elapsed / Self.holdSeconds, 1)

        guard elapsed >= Self.holdSeconds else { return .inProgress }
        guard restingCount >= Self.minimumHoldSamples else { return .failed(.tooFewSamples) }
        gyroBias = restingSum * (1 / Double(restingCount))
        advance(to: .sweepSideways)
        return .inProgress
    }

    private mutating func processSweep(_ reading: MotionReading, elapsed: Double) -> CalibrationStatus {
        let rate = reading.rotationRate - gyroBias
        if rate.magnitude > Self.sweepMotionFloor {
            sweepSamples.append(rate)
        }
        progress = min(elapsed / Self.sweepSeconds, 1)
        guard elapsed >= Self.sweepSeconds else { return .inProgress }

