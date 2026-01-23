import Foundation

/// The results of a test session, formatted for pasting into a GitHub issue.
/// It holds no device names, because macOS AirPods names often include a person's name.
public struct SessionReport: Sendable {
    public var appVersion: String
    public var macOSVersion: String
    public var motion: SampleRateSnapshot
    public var sensorLocations: [String]
    public var pressCounts: [StemPress: Int]
    public var events: [String]

