import CoreAudio
import Foundation

/// Finds connected AirPods among the Mac's sound outputs and can switch to them.
enum AudioOutput {
    private static let namesToMatch = ["AirPods", "Beats"]

    static var airPodsDevice: AudioDeviceID? {
        allDevices().first { device in
            let transport: UInt32 = read(kAudioDevicePropertyTransportType, of: device) ?? 0
            guard transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE,
                  hasOutput(device), let name = name(of: device) else { return false }
            return namesToMatch.contains { name.localizedCaseInsensitiveContains($0) }
        }
    }

    static var isUsingAirPods: Bool {
        guard let airPods = airPodsDevice else { return false }
        let current: AudioDeviceID? = read(kAudioHardwarePropertyDefaultOutputDevice, of: AudioObjectID(kAudioObjectSystemObject))
        return current == airPods
    }

    @discardableResult
    static func useAirPods() -> Bool {
        guard var device = airPodsDevice else { return false }
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &device
        )
        return status == noErr
    }

    private static func allDevices() -> [AudioDeviceID] {
        var address = address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices
    }

