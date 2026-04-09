import Foundation

public struct CaseOutput: Equatable, Sendable {
    public var point: PointerPoint
    public var gesture: CaseGesture?
}

/// Combines calibration, tap detection, and pointer movement into one input.
public struct CaseInputProcessor: Sendable {
    public let calibration: CaseCalibration

