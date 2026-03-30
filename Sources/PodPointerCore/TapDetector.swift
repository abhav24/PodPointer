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
