import CoreAudio
import Foundation

/// Finds connected AirPods among the Mac's sound outputs and can switch to them.
enum AudioOutput {
    private static let namesToMatch = ["AirPods", "Beats"]

    static var airPodsDevice: AudioDeviceID? {
        allDevices().first { device in
