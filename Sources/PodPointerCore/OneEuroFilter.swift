import Foundation

/// One Euro filter (Casiez et al., CHI 2012): smooths heavily when the input is
/// slow, which removes jitter, and lightly when it is fast, which reduces lag.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var lastFiltered: Double?
