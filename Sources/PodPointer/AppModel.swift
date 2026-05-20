import AppKit
import PodPointerCore
import SwiftUI

struct DisplayOption: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

@MainActor
final class AppModel: ObservableObject {
    static let version = "0.1.0"

    private static let calibrationKey = "caseCalibration"
    private static let staleSampleSeconds = 0.5
    private static let realMousePauseSeconds = 1.0
    private static let pointerTimeConstant = 0.035
    private static let maxLogLines = 200

    // Motion
    @Published private(set) var permission = "Not asked yet"
    @Published private(set) var isConnected = false
    @Published private(set) var isReceivingMotion = false
    @Published private(set) var rate = SampleRateSnapshot.empty
    @Published private(set) var sensorLocation = "-"
    @Published private(set) var strongestJolt = 0.0
    @Published var keepsAudioActive = false {
        didSet { updateSilentAudio() }
    }

    // Calibration
    @Published private(set) var isCalibrated = false
    @Published private(set) var calibrationStep: CalibrationStep?
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var calibrationTaps = 0
    @Published private(set) var calibrationMessage: String?

    // Control
    @Published private(set) var mode = ControlMode.off
    @Published private(set) var isPointerOn = true
    @Published private(set) var displays: [DisplayOption] = []
    @Published var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID() {
        didSet {
            applyDisplayShape()
            updateOverlay()
        }
    }
    @Published var pointerConfiguration = PointerConfiguration() {
        didSet { processor?.pointerConfiguration = pointerConfiguration }
    }
    @Published var tapSensitivity = 1.0 {
        didSet { processor?.tapSensitivity = tapSensitivity }
    }
    @Published var sendsActions = false
    @Published private(set) var hasAccessibility = InputSender.isTrusted
    @Published private(set) var gestureCounts: [CaseGesture: Int] = [:]

    @Published private(set) var log: [String] = []

    private let motion = MotionController()
    private let overlay = LaserOverlay()
    private let silentAudio = SilentAudio()
    private var processor: CaseInputProcessor?
    private var calibrationSession: CalibrationSession?
    private var tracker = SampleRateTracker()
    private var sensorLocationsSeen: [String] = []
    private var previousAcceleration: Vector3?
    private var joltSinceLastPublish = 0.0
    private var lastSampleDate: Date?
    private var lastPublishDate = Date.distantPast
    private var targetPoint = PointerPoint.center
    private var shownPoint = PointerPoint.center
    private var lastFrameDate = Date()
    private var isPausedForRealMouse = false
    private var hasWarnedAboutSensor = false
    private var timers: [Timer] = []
    private var hasStarted = false

    private static let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var canUsePointer: Bool { isCalibrated && calibrationStep == nil }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        refreshDisplays()
        loadCalibration()

        motion.onReading = { [weak self] reading, location in
            self?.handle(reading, sensorLocation: location)
        }
        motion.onConnectionChange = { [weak self] connected in
            self?.isConnected = connected
            self?.addLog(connected ? "AirPods connected" : "AirPods disconnected")
        }
        motion.onError = { [weak self] in self?.addLog("Motion error: \($0)") }

        if motion.isAvailable {
            motion.start()
            addLog("Waiting for motion from the AirPods")
        } else {
            addLog("Motion from AirPods isn't available right now")
        }

        addTimer(interval: 1.0 / 120) { $0.drawPointer() }
        addTimer(interval: 0.25) { $0.checkHealth() }
    }

    func setMode(_ newMode: ControlMode) {
        mode = newMode
        isPointerOn = true
        isPausedForRealMouse = false
        addLog("Mode: \(newMode.rawValue)")
        if newMode == .mouse {
            syncToCursor()
        } else {
            place(at: .center)
        }
        updateOverlay()
    }

    func recenter() {
        place(at: .center)
        addLog("Recentered")
    }

    func startCalibration() {
        guard isReceivingMotion else {
            calibrationMessage = "Motion isn't arriving yet. Check the setup steps."
            return
        }
        setMode(.off)
        calibrationSession = CalibrationSession(sensorLocation: sensorLocation)
        calibrationStep = .holdStill
        calibrationProgress = 0
        calibrationTaps = 0
        calibrationMessage = nil
        addLog("Calibration started")
    }

    func cancelCalibration() {
        calibrationSession = nil
        calibrationStep = nil
        calibrationMessage = "Calibration canceled."
        addLog("Calibration canceled")
    }

    func requestAccessibility() {
        InputSender.requestTrust()
    }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            Self.displayID(of: screen).map { DisplayOption(id: $0, name: screen.localizedName) }
        }
        if !displays.contains(where: { $0.id == selectedDisplayID }), let first = displays.first {
            selectedDisplayID = first.id
        }
        applyDisplayShape()
    }

    func copyReport() {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let report = SessionReport(
            appVersion: Self.version,
            macOSVersion: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
            motion: rate,
            sensorLocations: sensorLocationsSeen,
            isCalibrated: isCalibrated,
            gestureCounts: gestureCounts,
            events: log
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report.markdown, forType: .string)
        addLog("Copied test report")
    }

    private func handle(_ reading: MotionReading, sensorLocation location: String) {
        tracker.record(reading.timestamp)
        lastSampleDate = Date()
        if !isReceivingMotion {
            isReceivingMotion = true
            addLog("Motion started")
            updateOverlay()
        }
        noteSensor(location)
        publishStats(for: reading)

        if calibrationSession != nil {
            continueCalibration(with: reading)
            return
        }
        guard var current = processor else { return }
        let output = current.process(reading)
        processor = current
        targetPoint = output.point
        if let gesture = output.gesture {
            perform(gesture)
        }
    }

    private func noteSensor(_ location: String) {
        guard location != sensorLocation else { return }
        sensorLocation = location
        if !sensorLocationsSeen.contains(location) {
            sensorLocationsSeen.append(location)
        }
        addLog("Motion is coming from: \(location)")
        if let processor, processor.calibration.sensorLocation != location, !hasWarnedAboutSensor {
            hasWarnedAboutSensor = true
            calibrationMessage = "Motion moved to the other AirPod, so please calibrate again."
            addLog("Calibration doesn't match this AirPod")
        }
    }

    private func publishStats(for reading: MotionReading) {
        if let previous = previousAcceleration {
            joltSinceLastPublish = max(joltSinceLastPublish, (reading.userAcceleration - previous).magnitude)
        }
        previousAcceleration = reading.userAcceleration

        // The window only needs a few updates a second.
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

    private func moveCursor(to point: PointerPoint) {
        let bounds = CGDisplayBounds(selectedDisplayID)
        CGWarpMouseCursorPosition(CGPoint(
            x: bounds.minX + point.x * (bounds.width - 1),
            y: bounds.minY + point.y * (bounds.height - 1)
        ))
    }

    private func checkHealth() {
        hasAccessibility = KeySender.isTrusted
        permission = motion.authorizationDescription

        // Warping creates no mouse events, so a recent one means someone moved a real mouse.
        // The grace period allows for the mouse movement that selected this mode.
        if pointerMode == .cursor,
           Date().timeIntervalSince(pointerModeChangeDate) > Self.cursorGraceSeconds,
           CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved) < 0.25 {
            setPointerMode(.off)
            addLog("Real mouse moved, so head control turned off")
        }

        guard let lastSampleDate, !isStale else { return }
        if Date().timeIntervalSince(lastSampleDate) > Self.staleSampleSeconds {
            isStale = true
            tracker.reset()
            rate = .empty
            addLog("Motion samples stopped")
            overlay.hide()
        }
    }

    private func showOverlayIfNeeded() {
        guard pointerMode == .laser, !isStale,
              let screen = NSScreen.screens.first(where: { Self.displayID(of: $0) == selectedDisplayID }) else {
            overlay.hide()
            return
        }
        overlay.show(on: screen)
    }

    private func addLog(_ message: String) {
        log.append("\(Self.timeFormat.string(from: Date())) \(message)")
        if log.count > Self.maxLogLines {
            log.removeFirst(log.count - Self.maxLogLines)
        }
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
