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
