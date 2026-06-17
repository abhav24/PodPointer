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

