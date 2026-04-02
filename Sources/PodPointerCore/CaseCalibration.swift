import Foundation

/// What calibration learns about one way of holding the case.
///
/// The AirPods sit at an arbitrary angle in your hand, so the sensor's axes
/// don't line up with the screen. Calibration finds which rotation means
/// "right" and which means "up", then measures how hard your taps are.
public struct CaseCalibration: Codable, Equatable, Sendable {
    /// Unit axis. Positive rotation around it moves the pointer right.
    public var horizontalAxis: Vector3
    /// Unit axis. Positive rotation around it moves the pointer up.
    public var verticalAxis: Vector3
    /// The gyroscope's reading at rest, in radians per second.
    public var gyroBias: Vector3
    /// The change in acceleration between samples that counts as a tap, in g.
    public var tapThreshold: Double
    /// Which AirPod was sending motion. The other one sits at a different angle.
    public var sensorLocation: String

    public init(
        horizontalAxis: Vector3,
        verticalAxis: Vector3,
        gyroBias: Vector3,
        tapThreshold: Double,
        sensorLocation: String
    ) {
        self.horizontalAxis = horizontalAxis
        self.verticalAxis = verticalAxis
        self.gyroBias = gyroBias
        self.tapThreshold = tapThreshold
        self.sensorLocation = sensorLocation
    }
}

public enum CalibrationStep: Equatable, Sendable {
    case holdStill
    case sweepSideways
    case sweepVertically
    case tap
}
