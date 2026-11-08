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

    public init(
        appVersion: String,
        macOSVersion: String,
        motion: SampleRateSnapshot,
        sensorLocations: [String],
        pressCounts: [StemPress: Int],
        events: [String]
    ) {
        self.appVersion = appVersion
        self.macOSVersion = macOSVersion
        self.motion = motion
        self.sensorLocations = sensorLocations
        self.pressCounts = pressCounts
        self.events = events
    }

    public var markdown: String {
        let locations = sensorLocations.isEmpty ? "none" : sensorLocations.joined(separator: ", ")
        let presses = StemPress.allCases
            .map { "\($0.rawValue): \(pressCounts[$0, default: 0])" }
            .joined(separator: ", ")
        return """
        ## PodPointer test report

        - App version: \(appVersion)
        - macOS: \(macOSVersion)
        - AirPods model: (fill in)
        - Slide app and version: (fill in)

        ### Measured
        - Motion rate: \(String(format: "%.1f", motion.hertz)) Hz
        - p95 sample interval: \(String(format: "%.0f", motion.p95IntervalMilliseconds)) ms
        - Longest gap in the last window: \(String(format: "%.0f", motion.maxGapMilliseconds)) ms
        - Sensor locations seen: \(locations)
        - Stem presses received: \(presses)

        ### Results (fill in)
        - Stem presses work while slides are in front: yes / no
        - Pointer feels usable while presenting: yes / no
        - Laser overlay appears over the slideshow: yes / no
        - Motion continues with one AirPod in: yes / no
        - Motion continues with an AirPod held in the hand: yes / no

        ### Event log
        ```
        \(events.joined(separator: "\n"))
        ```
        """
    }
}
