import Foundation

/// What calibration learns about one way of holding the case.
///
/// The AirPods sit at an arbitrary angle in your hand, so the sensor's axes
/// don't line up with the screen. Calibration finds which rotation means
/// "right" and which means "up", then measures how hard your taps are.
public struct CaseCalibration: Codable, Equatable, Sendable {
    /// Unit axis. Positive rotation around it moves the pointer right.
    public var horizontalAxis: Vector3
