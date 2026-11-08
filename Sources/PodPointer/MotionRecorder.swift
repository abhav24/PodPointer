import Foundation
import PodPointerCore

/// Saves raw motion and test events from setup to a local file, for tuning tap
/// detection against real taps. Each setup run replaces the previous file, and
/// nothing leaves the Mac.
final class MotionRecorder {
    private static let flushLineCount = 200

    private var handle: FileHandle?
    private var pending: [String] = []

    static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("PodPointer/last-setup-motion.csv")
    }

    func start() {
        stop()
        guard let url = Self.fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try FileHandle(forWritingTo: url)
            pending = ["time,ax,ay,az,rx,ry,rz,event"]
        } catch {
            handle = nil
        }
    }

    func record(_ reading: MotionReading) {
        guard handle != nil else { return }
        let acceleration = reading.userAcceleration
        let rotation = reading.rotationRate
        pending.append(String(
            format: "%.4f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,",
            reading.timestamp,
            acceleration.x, acceleration.y, acceleration.z,
            rotation.x, rotation.y, rotation.z
        ))
        if pending.count >= Self.flushLineCount {
            flush()
        }
    }

    func mark(_ event: String, at time: Double) {
        guard handle != nil else { return }
        pending.append(String(format: "%.4f,,,,,,,", time) + event)
    }

    func stop() {
        flush()
        try? handle?.close()
        handle = nil
    }

    private func flush() {
        guard let handle, !pending.isEmpty else { return }
        let text = pending.joined(separator: "\n") + "\n"
        pending.removeAll()
        if let data = text.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
    }
}
