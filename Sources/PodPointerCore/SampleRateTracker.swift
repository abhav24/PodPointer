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

    public mutating func reset() {
        timestamps.removeAll()
    }

    public var snapshot: SampleRateSnapshot {
        guard timestamps.count >= 2, let first = timestamps.first, let last = timestamps.last, last > first else {
            return .empty
        }
        let intervals = zip(timestamps.dropFirst(), timestamps).map { $0 - $1 }.sorted()
        let p95Index = min(intervals.count - 1, Int((Double(intervals.count) * 0.95).rounded(.down)))
        return SampleRateSnapshot(
            hertz: Double(intervals.count) / (last - first),
            p95IntervalMilliseconds: intervals[p95Index] * 1000,
            maxGapMilliseconds: (intervals.last ?? 0) * 1000
        )
    }
}
