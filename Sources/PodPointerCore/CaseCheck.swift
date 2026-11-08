import Foundation

public enum CaseCheckStep: Equatable, Sendable {
    case connect
    case earDetection
    case placeInCase
    case watchingCase
    case motionLost
    case calibrate
    case tapTest
    case gestureTest
    case moveTest
    case pointTest
    case results
}

public enum GestureAnswer: Equatable, Sendable {
    case correct
    case recognized(CaseGesture)
    case nothing
}

public struct CaseCheckResults: Equatable, Sendable {
    public var tapsHit = 0
    public var tapsAsked = CaseCheck.tapPrompts
    public var extraTaps = 0
    public var gesturesHit = 0
    public var gesturesAsked = CaseCheck.gesturePrompts.count
    public var falseTapsWhileMoving = 0
    public var targetsHit = 0
    public var targetsAsked = CaseCheck.targets.count

    public var tapsPassed: Bool { tapsHit >= 8 && extraTaps <= 1 }
    public var gesturesPassed: Bool { gesturesHit >= 7 }
    public var movingPassed: Bool { falseTapsWhileMoving <= 1 }
    public var pointingPassed: Bool { targetsHit >= 4 }
    public var passed: Bool { tapsPassed && gesturesPassed && movingPassed && pointingPassed }
}

/// Walks through testing the case and scores the results, so nobody has to
/// count taps or judge by feel. It runs from motion and taps alone, so it can
/// be tested without hardware.
public struct CaseCheck: Equatable, Sendable {
    public static let tapPrompts = 10
    public static let tapIntervalSeconds = 2.5
    public static let getReadySeconds = 3.0
    public static let gesturePrompts: [CaseGesture] = [
        .single, .double, .triple,
        .double, .single, .triple,
        .double, .triple, .single
    ]
    public static let gesturePauseSeconds = 1.2
    public static let gestureTimeoutSeconds = 6.0
    public static let moveSeconds = 15.0
    public static let targetTimeoutSeconds = 15.0
    public static let targets = [
        PointerPoint(x: 0.2, y: 0.25),
        PointerPoint(x: 0.8, y: 0.25),
        PointerPoint(x: 0.5, y: 0.5),
        PointerPoint(x: 0.2, y: 0.75),
        PointerPoint(x: 0.8, y: 0.75)
    ]
    /// As a fraction of the display height.
    public static let targetRadius = 0.1

    private static let motionLostSeconds = 3.0
    private static let movingRotationSpeed = 1.0
    private static let requiredMovingSeconds = 0.5
    private static let maximumMovingStep = 0.1

    public private(set) var step = CaseCheckStep.connect
    public private(set) var results = CaseCheckResults()
    public private(set) var targetIndex = 0
    public private(set) var gestureIndex = 0
    /// What the last prompt recognized. Nil before the first answer.
    public private(set) var lastGestureAnswer: GestureAnswer?

    private var gesturePromptStart = 0.0
    private var lastSampleTime = -Double.infinity
    private var stepStart = 0.0
    private var movingSeconds = 0.0
    private var promptsHit: Set<Int> = []
    private var targetStart = 0.0

    public init() {}

    public var currentTarget: PointerPoint? {
        step == .pointTest ? Self.targets[targetIndex] : nil
    }

    /// The prompt on screen, from 1. Nil while getting ready or outside the tap test.
    public func tapPromptNumber(at time: Double) -> Int? {
        guard step == .tapTest, time >= stepStart else { return nil }
        return min(Int((time - stepStart) / Self.tapIntervalSeconds), Self.tapPrompts - 1) + 1
    }

    public func secondsUntilTapsStart(at time: Double) -> Double {
        max(stepStart - time, 0)
    }

    /// The gesture to do now. Nil between prompts or outside the gesture test.
    public func gesturePrompt(at time: Double) -> CaseGesture? {
        guard step == .gestureTest, time >= gesturePromptStart else { return nil }
        return Self.gesturePrompts[gestureIndex]
    }

    public mutating func registerGesture(_ gesture: CaseGesture, at time: Double) {
        guard let expected = gesturePrompt(at: time) else { return }
        if gesture == expected {
            results.gesturesHit += 1
            lastGestureAnswer = .correct
        } else {
            lastGestureAnswer = .recognized(gesture)
        }
        advanceGesture(at: time)
    }

    public func moveSecondsLeft(at time: Double) -> Double {
        max(stepStart + Self.moveSeconds - time, 0)
    }

    public mutating func processMotion(rotationSpeed: Double, at time: Double) {
        let elapsed = min(max(time - lastSampleTime, 0), Self.maximumMovingStep)
        lastSampleTime = time

        switch step {
        case .connect:
            step = .earDetection
        case .motionLost:
            enterWatching(at: time)
        case .watchingCase:
            if rotationSpeed > Self.movingRotationSpeed {
                movingSeconds += elapsed
            }
            if movingSeconds >= Self.requiredMovingSeconds {
                step = .calibrate
            }
        default:
            break
        }
    }

    public mutating func confirmEarDetectionOff() {
        guard step == .earDetection else { return }
        step = .placeInCase
    }

    public mutating func confirmInCase(at time: Double) {
        guard step == .placeInCase else { return }
        enterWatching(at: time)
    }

    public mutating func returnToEarDetection() {
        step = .earDetection
    }

    public mutating func calibrationFinished(at time: Double) {
        guard step == .calibrate else { return }
        step = .tapTest
        stepStart = time + Self.getReadySeconds
        promptsHit.removeAll()
        results = CaseCheckResults()
    }

    /// Repeats the scored tests with the current calibration, after adjusting settings.
    public mutating func restartTests(at time: Double) {
        guard step == .results else { return }
        lastSampleTime = max(lastSampleTime, time)
        step = .calibrate
        calibrationFinished(at: time)
    }

    public mutating func registerTap(at time: Double, point: PointerPoint, aspectRatio: Double) {
        switch step {
        case .tapTest:
            guard let prompt = tapPromptNumber(at: time) else { return }
            if promptsHit.insert(prompt).inserted {
                results.tapsHit += 1
            } else {
                results.extraTaps += 1
            }
        case .moveTest:
            results.falseTapsWhileMoving += 1
        case .pointTest:
            let target = Self.targets[targetIndex]
            let horizontal = (point.x - target.x) * aspectRatio
            let vertical = point.y - target.y
            guard (horizontal * horizontal + vertical * vertical).squareRoot() <= Self.targetRadius else { return }
            results.targetsHit += 1
            advanceTarget(at: time)
        default:
            break
        }
    }

    public mutating func tick(at time: Double) {
        switch step {
        case .watchingCase, .calibrate, .tapTest, .gestureTest, .moveTest, .pointTest:
            if time - max(lastSampleTime, step == .watchingCase ? stepStart : -Double.infinity) >= Self.motionLostSeconds {
                step = .motionLost
                return
            }
        default:
            return
        }

        switch step {
        case .tapTest where time >= stepStart + Double(Self.tapPrompts) * Self.tapIntervalSeconds:
            step = .gestureTest
            gestureIndex = 0
            gesturePromptStart = time + Self.getReadySeconds
            lastGestureAnswer = nil
        case .gestureTest where time >= gesturePromptStart + Self.gestureTimeoutSeconds:
            lastGestureAnswer = .nothing
            advanceGesture(at: time)
        case .moveTest where time >= stepStart + Self.moveSeconds:
            step = .pointTest
            targetIndex = 0
            targetStart = time
        case .pointTest where time >= targetStart + Self.targetTimeoutSeconds:
            advanceTarget(at: time)
        default:
            break
        }
    }

