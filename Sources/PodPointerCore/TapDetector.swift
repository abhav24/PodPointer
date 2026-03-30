import Foundation

/// Finds taps on the case: a short jolt of acceleration while the hand is steady.
public struct TapDetector: Sendable {
    public enum Event: Equatable, Sendable {
        case none
        /// A jolt began. It may still turn out to be a hand movement.
        case impulseStarted
        case tap
        case rejected
    }

    public var threshold: Double

    private static let stillRotationLimit = 0.9
    private static let stillWindowSeconds = 0.25
    private static let maximumImpulseSeconds = 0.16
    private static let afterTapSeconds = 0.12
    private static let afterRejectSeconds = 0.2
    private static let resetGapSeconds = 0.5

    private var previousAcceleration: Vector3?
