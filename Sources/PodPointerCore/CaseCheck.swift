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
