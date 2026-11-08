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

