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
    case turnRight
    case sweepVertically
    case turnUp
    case tap
}

public enum CalibrationFailure: String, Error, Equatable, Sendable {
    case tooFewSamples = "Motion samples arrived too slowly. Check the connection and try again."
    case tooLittleMovement = "There wasn't enough movement. Sweep the case further and try again."
    case unclearMovement = "The movement was hard to read. Keep each sweep in one direction and try again."
    case axesTooSimilar = "The two sweeps looked the same. Sweep sideways, then up and down, and try again."
    case noDirection = "The case didn't turn far enough. Turn it further, then stop, and try again."
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
    private static let sweepSeconds = 3.0
    private static let turnTimeoutSeconds = 8.0
    private static let tapTimeoutSeconds = 10.0
    private static let settleSeconds = 0.4
    private static let minimumHoldSamples = 20
    private static let minimumSweepSamples = 12
    private static let minimumTaps = 3
    private static let holdMotionLimit = 0.5
    private static let sweepMotionFloor = 0.35
    private static let minimumAxisEnergy = 0.6
    private static let minimumAxisSeparation = 0.5
    private static let requiredTurnRadians = 15 * Double.pi / 180
    private static let maximumTurnStep = 0.1
    private static let tapPeakSeconds = 0.15
    private static let tapSpacingSeconds = 0.25

    public private(set) var step = CalibrationStep.holdStill
    public private(set) var progress = 0.0
    public private(set) var tapsFound = 0
    /// True while waiting for the hand to stop before a step begins. Motion left
    /// over from the previous step is ignored, so it can't affect this one.
    public private(set) var isSettling = false

    private let sensorLocation: String
    private var stepStart: Double?
    private var stillSince: Double?
    private var previousAcceleration: Vector3?
    private var previousTime: Double?

    private var restingSum = Vector3.zero
    private var restingCount = 0
    private var noiseFloor = 0.0
    private var gyroBias = Vector3.zero

    private var sweepSamples: [Vector3] = []
    private var pendingAxis = Vector3.zero
    private var turnedRadians = 0.0
    private var horizontalAxis = Vector3.zero
    private var verticalAxis = Vector3.zero

    private var tapPeaks: [Double] = []
    private var currentPeak: Double?
    private var currentPeakStart = -Double.infinity

    public init(sensorLocation: String) {
        self.sensorLocation = sensorLocation
    }

    public mutating func process(_ reading: MotionReading) -> CalibrationStatus {
        let time = reading.timestamp
        let impulse = previousAcceleration.map { (reading.userAcceleration - $0).magnitude } ?? 0
        let sampleStep = previousTime.map { min(max(time - $0, 0), Self.maximumTurnStep) } ?? 0
        previousAcceleration = reading.userAcceleration
        previousTime = time

        if isSettling {
            guard finishSettling(reading, at: time) else { return .inProgress }
        }
        let start = stepStart ?? time
        stepStart = start
        let elapsed = time - start

        switch step {
        case .holdStill:
            return processHold(reading, impulse: impulse, elapsed: elapsed)
        case .sweepSideways, .sweepVertically:
            return processSweep(reading, elapsed: elapsed)
        case .turnRight, .turnUp:
            return processTurn(reading, sampleStep: sampleStep, elapsed: elapsed)
        case .tap:
            return processTap(impulse: impulse, time: time, elapsed: elapsed)
        }
    }

    private mutating func finishSettling(_ reading: MotionReading, at time: Double) -> Bool {
        guard (reading.rotationRate - gyroBias).magnitude < Self.holdMotionLimit else {
            stillSince = nil
            return false
        }
        let since = stillSince ?? time
        stillSince = since
        guard time - since >= Self.settleSeconds else { return false }
        isSettling = false
        return true
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

        guard sweepSamples.count >= Self.minimumSweepSamples else { return .failed(.tooLittleMovement) }
        guard let axis = Self.principalAxis(of: sweepSamples) else { return .failed(.unclearMovement) }
        sweepSamples.removeAll()

        if step == .sweepSideways {
            pendingAxis = axis
            advance(to: .turnRight)
            return .inProgress
        }

        // Remove any part of the vertical axis that also means "sideways".
        let separated = axis - horizontalAxis * axis.dot(horizontalAxis)
        guard separated.magnitude >= Self.minimumAxisSeparation else { return .failed(.axesTooSimilar) }
        pendingAxis = separated.normalized
        advance(to: .turnUp)
        return .inProgress
    }

    /// Sets an axis's direction from one deliberate turn. Using the total angle
    /// means a small wind-up in the opposite direction doesn't matter.
    private mutating func processTurn(_ reading: MotionReading, sampleStep: Double, elapsed: Double) -> CalibrationStatus {
        let rate = reading.rotationRate - gyroBias
        turnedRadians += rate.dot(pendingAxis) * sampleStep
        progress = min(abs(turnedRadians) / Self.requiredTurnRadians, 1)

        if abs(turnedRadians) >= Self.requiredTurnRadians, rate.magnitude < Self.holdMotionLimit {
            let axis = turnedRadians > 0 ? pendingAxis : pendingAxis * -1
            if step == .turnRight {
                horizontalAxis = axis
                advance(to: .sweepVertically)
            } else {
                verticalAxis = axis
                advance(to: .tap)
            }
            return .inProgress
        }
        return elapsed >= Self.turnTimeoutSeconds ? .failed(.noDirection) : .inProgress
    }

    private mutating func processTap(impulse: Double, time: Double, elapsed: Double) -> CalibrationStatus {
        if let peak = currentPeak {
            if time - currentPeakStart <= Self.tapPeakSeconds {
                currentPeak = max(peak, impulse)
            } else {
                tapPeaks.append(peak)
                currentPeak = nil
                tapsFound = tapPeaks.count
            }
        } else if impulse >= max(noiseFloor * 2, 0.02), time - currentPeakStart >= Self.tapSpacingSeconds {
            currentPeak = impulse
            currentPeakStart = time
        }

        progress = Double(min(tapPeaks.count, Self.requiredTaps)) / Double(Self.requiredTaps)
        guard tapPeaks.count >= Self.requiredTaps || elapsed >= Self.tapTimeoutSeconds else {
            return .inProgress
        }
        guard tapPeaks.count >= Self.minimumTaps else { return .failed(.tooFewTaps) }

        let median = tapPeaks.sorted()[tapPeaks.count / 2]
        guard median > noiseFloor * 1.5 else { return .failed(.tapsTooWeak) }
        return .finished(CaseCalibration(
            horizontalAxis: horizontalAxis,
            verticalAxis: verticalAxis,
            gyroBias: gyroBias,
            tapThreshold: max(median * 0.6, noiseFloor * 1.5),
            sensorLocation: sensorLocation
        ))
    }

    private mutating func advance(to next: CalibrationStep) {
        step = next
        stepStart = nil
        progress = 0
    }

    /// Finds the axis most of the rotation happened around, using power iteration.
    /// Its sign follows the first movement, so "start by moving right" defines right.
    private static func principalAxis(of samples: [Vector3]) -> Vector3? {
        guard let largest = samples.max(by: { $0.magnitude < $1.magnitude }) else { return nil }

        var axis = largest.normalized
        for _ in 0..<25 {
            var next = Vector3.zero
            for sample in samples {
                next = next + sample * sample.dot(axis)
            }
            axis = next.normalized
        }

        let total = samples.reduce(0) { $0 + $1.dot($1) }
        let alongAxis = samples.reduce(0) { $0 + pow($1.dot(axis), 2) }
        guard total > 0, alongAxis / total >= minimumAxisEnergy else { return nil }

        let firstMovement = samples.prefix(5).reduce(0) { $0 + $1.dot(axis) }
        return firstMovement >= 0 ? axis : axis * -1
    }
}
