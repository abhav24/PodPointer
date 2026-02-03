import CoreMotion
import Foundation

struct MotionSample {
    let yaw: Double
    let pitch: Double
    let roll: Double
    let timestamp: Double
    let sensorLocation: String
}

/// Streams head motion from connected AirPods. Callbacks arrive on the main queue.
final class MotionController: NSObject, CMHeadphoneMotionManagerDelegate {
    var onSample: ((MotionSample) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private let manager = CMHeadphoneMotionManager()
