import AppKit
import PodPointerCore
import SwiftUI

enum PointerMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case laser = "Laser dot"
    case cursor = "Mouse cursor"

    var id: String { rawValue }
}

struct DisplayOption: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

@MainActor
final class AppModel: ObservableObject {
    static let version = "0.1.0"
    private static let staleSampleSeconds = 0.5
    private static let maxLogLines = 200
    private static let cursorGraceSeconds = 2.0

    // Motion
    @Published private(set) var permission = "Not asked yet"
    @Published private(set) var isConnected = false
    @Published private(set) var rate = SampleRateSnapshot.empty
    @Published private(set) var sensorLocation = "-"
    @Published private(set) var attitude = "-"
    @Published private(set) var isStale = true

    // Pointer
    @Published private(set) var pointerMode = PointerMode.off
    @Published private(set) var displays: [DisplayOption] = []
    @Published var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID() {
        didSet { showOverlayIfNeeded() }
    }
    @Published var configuration = PointerConfiguration() {
        didSet { mapper.configuration = configuration }
    }

    // Stem presses
    @Published private(set) var isListeningForStem = false
    @Published var sendsSlideKeys = false
    @Published private(set) var hasAccessibility = KeySender.isTrusted
    @Published private(set) var pressCounts: [StemPress: Int] = [:]

    @Published private(set) var log: [String] = []

    private let motion = MotionController()
    private let stem = StemController()
    private let overlay = LaserOverlay()
    private var mapper = PointerMapper()
    private var tracker = SampleRateTracker()
    private var debouncer = StemPressDebouncer()
    private var sensorLocations: [String] = []
    private var lastSampleDate: Date?
    private var lastPublishDate = Date.distantPast
    private var pointerModeChangeDate = Date.distantPast
    private var healthTimer: Timer?
    private var started = false

    private static let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func start() {
        guard !started else { return }
        started = true
        refreshDisplays()

        motion.onSample = { [weak self] in self?.handle($0) }
        motion.onConnectionChange = { [weak self] connected in
            self?.isConnected = connected
            self?.addLog(connected ? "AirPods motion connected" : "AirPods motion disconnected")
        }
        motion.onError = { [weak self] in self?.addLog("Motion error: \($0)") }
        stem.onPress = { [weak self] in self?.handle($0) }

        if motion.isAvailable {
            motion.start()
            addLog("Waiting for AirPods motion")
        } else {
            addLog("Headphone motion isn't available on this Mac")
        }

        healthTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
    }

