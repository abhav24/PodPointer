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
    public var checkResults: CaseCheckResults?
    public var events: [String]

    public init(
        appVersion: String,
        macOSVersion: String,
        motion: SampleRateSnapshot,
        sensorLocations: [String],
        isCalibrated: Bool,
        gestureCounts: [CaseGesture: Int],
        checkResults: CaseCheckResults? = nil,
        events: [String]
    ) {
        self.appVersion = appVersion
        self.macOSVersion = macOSVersion
        self.motion = motion
        self.sensorLocations = sensorLocations
        self.isCalibrated = isCalibrated
        self.gestureCounts = gestureCounts
        self.checkResults = checkResults
        self.events = events
    }

    public var markdown: String {
        let locations = sensorLocations.isEmpty ? "none" : sensorLocations.joined(separator: ", ")
        let gestures = CaseGesture.allCases
            .map { "\($0.rawValue): \(gestureCounts[$0, default: 0])" }
            .joined(separator: ", ")
        let check = checkResults.map { results in
            """
            - Taps detected: \(results.tapsHit) of \(results.tapsAsked), with \(results.extraTaps) extra
            - Single, double, and triple taps recognized: \(results.gesturesHit) of \(results.gesturesAsked)
            - False taps while moving: \(results.falseTapsWhileMoving)
            - Targets hit: \(results.targetsHit) of \(results.targetsAsked)
            - Overall: \(results.passed ? "passed" : "needs work")
            """
        } ?? "Not run"
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

        ### Case check
        \(check)

        ### With slides (fill in)
        - Slides change with taps: yes / no
        - Laser dot appears over a full-screen slideshow: yes / no

        ### Event log
        ```
        \(events.joined(separator: "\n"))
        ```
        """
    }
}
