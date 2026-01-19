import Foundation

public struct SampleRateSnapshot: Equatable, Sendable {
    public var hertz: Double
    public var p95IntervalMilliseconds: Double
    public var maxGapMilliseconds: Double

    public static let empty = SampleRateSnapshot(hertz: 0, p95IntervalMilliseconds: 0, maxGapMilliseconds: 0)
