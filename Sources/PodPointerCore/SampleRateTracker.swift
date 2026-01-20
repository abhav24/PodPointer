import Foundation

public struct SampleRateSnapshot: Equatable, Sendable {
    public var hertz: Double
    public var p95IntervalMilliseconds: Double
    public var maxGapMilliseconds: Double

    public static let empty = SampleRateSnapshot(hertz: 0, p95IntervalMilliseconds: 0, maxGapMilliseconds: 0)
}

/// Measures motion sample timing over a sliding window.
public struct SampleRateTracker: Sendable {
    public let windowSeconds: Double
    private var timestamps: [Double] = []

    public init(windowSeconds: Double = 5) {
        self.windowSeconds = windowSeconds
