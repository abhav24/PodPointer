import CoreMotion
import Foundation
import PodPointerCore

/// Streams motion from connected AirPods. Callbacks arrive on the main queue.
final class MotionController: NSObject, CMHeadphoneMotionManagerDelegate {
    var onReading: ((MotionReading, _ sensorLocation: String) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private let manager = CMHeadphoneMotionManager()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    var permissionDescription: String {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not asked yet"
        @unknown default: "Unknown"
        }
    }

    func start() {
        manager.delegate = self
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error {
                self?.onError?(error.localizedDescription)
            }
            guard let motion else { return }
            self?.onSample?(MotionSample(
                yaw: motion.attitude.yaw,
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                timestamp: motion.timestamp,
                sensorLocation: Self.describe(motion.sensorLocation)
            ))
        }
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.onConnectionChange?(true) }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.onConnectionChange?(false) }
    }

    private static func describe(_ location: CMDeviceMotion.SensorLocation) -> String {
        switch location {
        case .default: "default"
        case .headphoneLeft: "left"
        case .headphoneRight: "right"
        @unknown default: "unknown"
        }
    }
}
