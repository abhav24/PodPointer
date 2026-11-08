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

    func setPointerMode(_ mode: PointerMode) {
        pointerMode = mode
        pointerModeChangeDate = Date()
        addLog("Pointer mode: \(mode.rawValue)")
        mapper.recenter()
        showOverlayIfNeeded()
    }

    func recenter() {
        mapper.recenter()
        addLog("Recentered")
    }

    func setListeningForStem(_ enabled: Bool) {
        guard enabled != isListeningForStem else { return }
        if enabled {
            do {
                try stem.start()
                isListeningForStem = true
                addLog("Listening for stem presses")
            } catch {
                stem.stop()
                addLog("Couldn't start stem listening: \(error.localizedDescription)")
            }
        } else {
            stem.stop()
            isListeningForStem = false
            addLog("Stopped listening for stem presses")
        }
    }

    func requestAccessibility() {
        KeySender.requestTrust()
    }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            Self.displayID(of: screen).map { DisplayOption(id: $0, name: screen.localizedName) }
        }
        if !displays.contains(where: { $0.id == selectedDisplayID }), let first = displays.first {
            selectedDisplayID = first.id
        }
    }

    func copyReport() {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let report = SessionReport(
            appVersion: Self.version,
            macOSVersion: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
            motion: rate,
            sensorLocations: sensorLocations,
            pressCounts: pressCounts,
            events: log
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report.markdown, forType: .string)
        addLog("Copied test report")
    }

    private func handle(_ sample: MotionSample) {
        tracker.record(sample.timestamp)
        lastSampleDate = Date()
        if sample.sensorLocation != sensorLocation {
            sensorLocation = sample.sensorLocation
            if !sensorLocations.contains(sample.sensorLocation) {
                sensorLocations.append(sample.sensorLocation)
            }
            addLog("Motion sensor: \(sample.sensorLocation)")
        }

        let point = mapper.map(yawRadians: sample.yaw, pitchRadians: sample.pitch, at: sample.timestamp)
        switch pointerMode {
        case .off:
            break
        case .laser:
            overlay.move(to: point)
        case .cursor:
            moveCursor(to: point)
        }
        if isStale {
            isStale = false
            addLog("Motion samples started")
            showOverlayIfNeeded()
        }

        // The pointer updates on every sample, but the window only needs a few updates a second.
        let now = Date()
        guard now.timeIntervalSince(lastPublishDate) >= 0.2 else { return }
        lastPublishDate = now
        rate = tracker.snapshot
        attitude = String(
            format: "yaw %.0f°, pitch %.0f°, roll %.0f°",
            sample.yaw * 180 / .pi,
            sample.pitch * 180 / .pi,
            sample.roll * 180 / .pi
        )
    }

    private func handle(_ press: StemPress) {
        guard debouncer.shouldAccept(press, at: ProcessInfo.processInfo.systemUptime) else { return }
        pressCounts[press, default: 0] += 1
        let action = StemAction(press: press)
        hasAccessibility = KeySender.isTrusted

        switch action {
        case .recenter:
            mapper.recenter()
            addLog("Stem press: double, recentered")
        case .nextSlide, .previousSlide:
            guard sendsSlideKeys else {
                addLog("Stem press: \(press.rawValue), would send \(action.rawValue) (sending is off)")
                return
            }
            guard hasAccessibility else {
                addLog("Stem press: \(press.rawValue), not sent because Accessibility is off")
                return
            }
            if action == .nextSlide {
                KeySender.nextSlide()
            } else {
                KeySender.previousSlide()
            }
            addLog("Stem press: \(press.rawValue), sent \(action.rawValue)")
        }
    }

