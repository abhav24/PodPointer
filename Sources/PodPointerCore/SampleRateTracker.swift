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
    }

    public mutating func record(_ time: Double) {
        timestamps.append(time)
        let oldestAllowed = time - windowSeconds
        if let firstKept = timestamps.firstIndex(where: { $0 >= oldestAllowed }), firstKept > 0 {
            timestamps.removeFirst(firstKept)
        }
    }
