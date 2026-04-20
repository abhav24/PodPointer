import Foundation

/// Test results formatted for a GitHub issue. It leaves out the AirPods' name,
/// which often includes a person's name.
public struct SessionReport: Sendable {
    public var appVersion: String
    public var macOSVersion: String
    public var motion: SampleRateSnapshot
    public var sensorLocations: [String]
    public var isCalibrated: Bool
    public var gestureCounts: [CaseGesture: Int]
    public var events: [String]

    public init(
        appVersion: String,
        macOSVersion: String,
        motion: SampleRateSnapshot,
        sensorLocations: [String],
        isCalibrated: Bool,
        gestureCounts: [CaseGesture: Int],
        events: [String]
    ) {
        self.appVersion = appVersion
        self.macOSVersion = macOSVersion
        self.motion = motion
        self.sensorLocations = sensorLocations
        self.isCalibrated = isCalibrated
        self.gestureCounts = gestureCounts
        self.events = events
    }

    public var markdown: String {
        let locations = sensorLocations.isEmpty ? "none" : sensorLocations.joined(separator: ", ")
        let gestures = CaseGesture.allCases
            .map { "\($0.rawValue): \(gestureCounts[$0, default: 0])" }
            .joined(separator: ", ")
        return """
        ## PodPointer test report

        - App version: \(appVersion)
        - macOS: \(macOSVersion)
        - AirPods model: (fill in)
        - Slide app and version: (fill in)

        ### Measured
        - Motion rate: \(String(format: "%.1f", motion.hertz)) Hz
        - Longest gap: \(String(format: "%.0f", motion.longestGapMilliseconds)) ms
        - AirPods sending motion: \(locations)
        - Calibrated: \(isCalibrated ? "yes" : "no")
        - Taps detected: \(gestures)

        ### Results (fill in)
        - Motion arrives from the open case: yes / no
        - Calibration finishes: yes / no
        - Taps out of 20 detected: __ / 20
        - False taps while pointing for 1 minute: __
        - Pointer feels usable: yes / no
        - Laser dot appears over a full-screen slideshow: yes / no

        ### Event log
        ```
        \(events.joined(separator: "\n"))
        ```
        """
    }
}
