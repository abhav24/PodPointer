import Foundation

public struct SampleRateSnapshot: Equatable, Sendable {
    public var hertz: Double
    public var longestGapMilliseconds: Double

    public static let empty = SampleRateSnapshot(hertz: 0, longestGapMilliseconds: 0)
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
        timestamps.removeAll { time - $0 > windowSeconds }
    }

    public mutating func reset() {
        timestamps.removeAll()
    }

    public var snapshot: SampleRateSnapshot {
        guard timestamps.count >= 2, let first = timestamps.first, let last = timestamps.last, last > first else {
            return .empty
        }
        let longestGap = zip(timestamps.dropFirst(), timestamps).map { $0 - $1 }.max() ?? 0
        return SampleRateSnapshot(
            hertz: Double(timestamps.count - 1) / (last - first),
            longestGapMilliseconds: longestGap * 1000
        )
    }
}
