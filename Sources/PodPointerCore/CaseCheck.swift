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
