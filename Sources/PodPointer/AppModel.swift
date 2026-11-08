import AppKit
import PodPointerCore
import SwiftUI

struct DisplayOption: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

enum AppStage: Equatable {
    case welcome
    case caseCheck
    case allowControl
    case trySlides
    case home
}

@MainActor
final class AppModel: ObservableObject {
    static let version = "0.1.0"

    private static let calibrationKey = "caseCalibration"
    private static let finishedSetupKey = "hasFinishedSetup"
    private static let rangeKey = "pointerRange"
    private static let steadinessKey = "pointerSteadiness"
    private static let sensitivityKey = "tapSensitivity"
    private static let multiTapKey = "multiTapWindow"
    private static let invertHorizontalKey = "invertHorizontal"
    private static let invertVerticalKey = "invertVertical"
    private static let staleSampleSeconds = 0.5
    private static let realMousePauseSeconds = 1.0
    private static let pointerTimeConstant = 0.035
    private static let maxLogLines = 200

    @Published private(set) var stage = AppStage.welcome
    @Published private(set) var lastAction: String?
    @Published var showsAdvanced = false

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
    @Published private(set) var calibrationIsSettling = false
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
        didSet {
            processor?.pointerConfiguration = pointerConfiguration
            UserDefaults.standard.set(pointerConfiguration.rangeDegrees, forKey: Self.rangeKey)
            UserDefaults.standard.set(pointerConfiguration.minCutoff, forKey: Self.steadinessKey)
            UserDefaults.standard.set(pointerConfiguration.invertHorizontal, forKey: Self.invertHorizontalKey)
            UserDefaults.standard.set(pointerConfiguration.invertVertical, forKey: Self.invertVerticalKey)
        }
    }
    @Published var tapSensitivity = 1.0 {
        didSet {
            processor?.tapSensitivity = tapSensitivity
            UserDefaults.standard.set(tapSensitivity, forKey: Self.sensitivityKey)
        }
    }
    @Published var multiTapWindow = 0.4 {
        didSet {
            processor?.multiTapWindow = multiTapWindow
            UserDefaults.standard.set(multiTapWindow, forKey: Self.multiTapKey)
        }
    }
    @Published var sendsActions = false
    @Published private(set) var hasAccessibility = InputSender.isTrusted
    @Published private(set) var gestureCounts: [CaseGesture: Int] = [:]

    @Published private(set) var log: [String] = []

    // Case check
    @Published private(set) var check: CaseCheck?
    @Published private(set) var checkClock = 0.0
    @Published private(set) var airPodsAudioFound = false
    @Published private(set) var soundUsesAirPods = false
    private var liveCheck: CaseCheck?
    private var lastCheckStep: CaseCheckStep?
    private var lastCheckResults: CaseCheckResults?

    private let motion = MotionController()
    private let overlay = LaserOverlay()
    private let silentAudio = SilentAudio()
    private let recorder = MotionRecorder()
    private var lastMarkedPrompt = ""
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
    private var hasStartedMotion = false

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
        loadSettings()
        loadCalibration()

        motion.onReading = { [weak self] reading, location in
            self?.handle(reading, sensorLocation: location)
        }
        motion.onConnectionChange = { [weak self] connected in
            self?.isConnected = connected
            self?.addLog(connected ? "AirPods connected" : "AirPods disconnected")
        }
        motion.onError = { [weak self] in self?.addLog("Motion error: \($0)") }

        addTimer(interval: 1.0 / 120) { $0.drawPointer() }
        addTimer(interval: 0.05) { $0.updateCheck() }
        addTimer(interval: 0.25) { $0.checkHealth() }

        if UserDefaults.standard.bool(forKey: Self.finishedSetupKey), isCalibrated {
            stage = .home
            startMotion()
        }
    }

    /// Starts setup. Motion starts here so the permission prompt follows the explanation.
    func beginSetup() {
        startMotion()
        liveCheck = CaseCheck()
        lastCheckStep = nil
        lastCheckResults = nil
        cancelCalibrationQuietly()
        setMode(.off)
        stage = .caseCheck
        recorder.start()
        lastMarkedPrompt = ""
        addLog("Setup started")
        updateCheck()
    }

    func startOver() {
        closeCaseCheck()
        UserDefaults.standard.set(false, forKey: Self.finishedSetupKey)
        sendsActions = false
        lastAction = nil
        calibrationMessage = nil
        stage = .welcome
    }

    func runTestsAgain() {
        liveCheck?.restartTests(at: Self.now)
        updateCheck()
    }

    /// Moves from the results to trying real slides.
    func continueToSlides() {
        closeCaseCheck()
        if InputSender.isTrusted {
            enterTrySlides()
        } else {
            stage = .allowControl
        }
    }

    func finishSetup() {
        UserDefaults.standard.set(true, forKey: Self.finishedSetupKey)
        setMode(.off)
        lastAction = nil
        stage = .home
        addLog("Setup finished")
    }

    private func enterTrySlides() {
        sendsActions = true
        stage = .trySlides
        setMode(.presenter)
    }

    private func startMotion() {
        guard !hasStartedMotion else { return }
        hasStartedMotion = true
        motion.start()
        addLog("Waiting for motion from the AirPods")
    }

    func showRecordingInFinder() {
        if let url = MotionRecorder.fileURL, FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func closeCaseCheck() {
        recorder.stop()
        liveCheck = nil
        check = nil
        lastCheckStep = nil
        cancelCalibrationQuietly()
        overlay.showTarget(at: nil, radius: 0)
        setMode(.off)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    func confirmEarDetectionOff() {
        liveCheck?.confirmEarDetectionOff()
        updateCheck()
    }

    func confirmInCase() {
        liveCheck?.confirmInCase(at: Self.now)
        updateCheck()
    }

    func returnToEarDetection() {
        liveCheck?.returnToEarDetection()
        updateCheck()
    }

    func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }

    func useAirPodsForSound() {
        addLog(AudioOutput.useAirPods() ? "Sound output set to AirPods" : "Couldn't set the sound output to AirPods")
        refreshSoundOutput()
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
            checkResults: lastCheckResults,
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
        liveCheck?.processMotion(rotationSpeed: reading.rotationRate.magnitude, at: Self.now)
        recorder.record(reading)

        if calibrationSession != nil {
            continueCalibration(with: reading)
            return
        }
        guard var current = processor else { return }
        let output = current.process(reading)
        processor = current
        targetPoint = output.point
        if output.tapped {
            recorder.mark("tap", at: reading.timestamp)
            liveCheck?.registerTap(at: Self.now, point: output.point, aspectRatio: pointerConfiguration.aspectRatio)
        }
        if let gesture = output.gesture {
            recorder.mark("gesture:\(gesture.rawValue)", at: reading.timestamp)
            liveCheck?.registerGesture(gesture, at: Self.now)
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
        strongestJolt = joltSinceLastPublish
        joltSinceLastPublish = 0
    }

    private func continueCalibration(with reading: MotionReading) {
        guard var session = calibrationSession else { return }
        let status = session.process(reading)
        calibrationSession = session
        calibrationStep = session.step
        calibrationProgress = session.progress
        calibrationTaps = session.tapsFound
        calibrationIsSettling = session.isSettling

        switch status {
        case .inProgress:
            break
        case let .finished(result):
            calibrationSession = nil
            calibrationStep = nil
            use(result)
            save(result)
            calibrationMessage = "Calibrated. Choose a mode to start."
            liveCheck?.calibrationFinished(at: Self.now)
            addLog(String(format: "Calibrated on the %@ AirPod, tap threshold %.2f g", result.sensorLocation, result.tapThreshold))
        case let .failed(failure):
            calibrationSession = nil
            calibrationStep = nil
            calibrationMessage = failure.rawValue
            addLog("Calibration failed: \(failure.rawValue)")
        }
    }

    private func perform(_ gesture: CaseGesture) {
        gestureCounts[gesture, default: 0] += 1
        // Taps during the case check are scored, and shouldn't control anything.
        if let step = liveCheck?.step, step != .results {
            addLog("Tap: \(gesture.rawValue)")
            return
        }
        guard let action = CaseAction(gesture: gesture, mode: mode) else {
            addLog("Tap: \(gesture.rawValue)")
            return
        }
        if action == .togglePointer {
            isPointerOn.toggle()
            addLog("Tap: \(gesture.rawValue), pointer \(isPointerOn ? "on" : "off")")
            if isPointerOn {
                mode == .mouse ? syncToCursor() : place(at: .center)
            }
            updateOverlay()
            return
        }
        guard sendsActions else {
            addLog("Tap: \(gesture.rawValue), would send \(action.rawValue) (sending is off)")
            return
        }
        hasAccessibility = InputSender.isTrusted
        guard hasAccessibility else {
            addLog("Tap: \(gesture.rawValue), not sent because Accessibility is off")
            return
        }
        switch action {
        case .nextSlide: InputSender.nextSlide()
        case .previousSlide: InputSender.previousSlide()
        case .click: InputSender.click(count: 1)
        case .doubleClick: InputSender.click(count: 2)
        case .togglePointer: break
        }
        lastAction = action.rawValue
        addLog("Tap: \(gesture.rawValue), sent \(action.rawValue)")
    }

    private func drawPointer() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFrameDate)
        lastFrameDate = now
        guard mode != .off, isPointerOn, canUsePointer, isReceivingMotion else { return }

        // Motion samples arrive far less often than the display refreshes, so
        // easing toward each sample keeps the pointer from looking jumpy.
        if mode == .mouse {
            let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
            if idle < Self.realMousePauseSeconds {
                isPausedForRealMouse = true
                return
            }
            if isPausedForRealMouse {
                isPausedForRealMouse = false
                syncToCursor()
                return
            }
        }
        shownPoint = shownPoint.eased(toward: targetPoint, elapsed: elapsed, timeConstant: Self.pointerTimeConstant)
        if mode == .presenter {
            overlay.move(to: shownPoint)
        } else {
            let bounds = CGDisplayBounds(selectedDisplayID)
            CGWarpMouseCursorPosition(CGPoint(
                x: bounds.minX + shownPoint.x * (bounds.width - 1),
                y: bounds.minY + shownPoint.y * (bounds.height - 1)
            ))
        }
    }

    /// Publishes the check a few times a second, and reacts when its step changes.
    private func updateCheck() {
        guard var current = liveCheck else { return }
        let now = Self.now
        current.tick(at: now)
        liveCheck = current

        let clock = (now * 4).rounded() / 4
        if clock != checkClock {
            checkClock = clock
        }
        if check != current {
            check = current
        }
        overlay.showTarget(at: current.currentTarget, radius: CaseCheck.targetRadius)

        let prompt = "step:\(current.step)"
            + (current.tapPromptNumber(at: now).map { " tap:\($0)" } ?? "")
            + (current.gesturePrompt(at: now).map { " ask:\($0.rawValue)" } ?? "")
        if prompt != lastMarkedPrompt {
            lastMarkedPrompt = prompt
            recorder.mark(prompt, at: now)
        }

        guard current.step != lastCheckStep else { return }
        lastCheckStep = current.step
        enterCheckStep(current.step, results: current.results)
    }

    private func enterCheckStep(_ step: CaseCheckStep, results: CaseCheckResults) {
        switch step {
        case .calibrate:
            startCalibration()
        case .tapTest:
            setMode(.off)
        case .pointTest:
            setMode(.presenter)
        case .motionLost:
            cancelCalibrationQuietly()
            setMode(.off)
            addLog("Case check: motion stopped")
        case .results:
            setMode(.off)
            lastCheckResults = results
            addLog("Case check finished: \(results.passed ? "passed" : "needs work")")
        default:
            break
        }
    }

    private func cancelCalibrationQuietly() {
        calibrationSession = nil
        calibrationStep = nil
    }

    private func refreshSoundOutput() {
        airPodsAudioFound = AudioOutput.airPodsDevice != nil
        soundUsesAirPods = AudioOutput.isUsingAirPods
    }

    private func checkHealth() {
        hasAccessibility = InputSender.isTrusted
        permission = motion.permissionDescription
        refreshSoundOutput()
        if stage == .allowControl, hasAccessibility {
            enterTrySlides()
        }

        guard isReceivingMotion, let lastSampleDate,
              Date().timeIntervalSince(lastSampleDate) > Self.staleSampleSeconds else { return }
        isReceivingMotion = false
        tracker.reset()
        previousAcceleration = nil
        rate = .empty
        strongestJolt = 0
        addLog("Motion stopped")
        if calibrationSession != nil {
            cancelCalibration()
            calibrationMessage = "Motion stopped, so calibration ended."
        }
        updateOverlay()
    }

    private func updateOverlay() {
        guard mode == .presenter, isPointerOn, canUsePointer, isReceivingMotion,
              let screen = NSScreen.screens.first(where: { Self.displayID(of: $0) == selectedDisplayID }) else {
            overlay.hide()
            return
        }
        overlay.show(on: screen)
        overlay.move(to: shownPoint)
    }

    private func place(at point: PointerPoint) {
        processor?.setPosition(point)
        targetPoint = point
        shownPoint = point
    }

    private func syncToCursor() {
        let bounds = CGDisplayBounds(selectedDisplayID)
        guard let cursor = CGEvent(source: nil)?.location, bounds.width > 0, bounds.height > 0 else { return }
        place(at: PointerPoint(
            x: (cursor.x - bounds.minX) / bounds.width,
            y: (cursor.y - bounds.minY) / bounds.height
        ))
    }

    private func applyDisplayShape() {
        let bounds = CGDisplayBounds(selectedDisplayID)
        guard bounds.height > 0 else { return }
        pointerConfiguration.aspectRatio = bounds.width / bounds.height
    }

    private func updateSilentAudio() {
        guard keepsAudioActive else {
            silentAudio.stop()
            addLog("Silent audio off")
            return
        }
        do {
            try silentAudio.start()
            addLog("Silent audio on")
        } catch {
            keepsAudioActive = false
            addLog("Couldn't start silent audio: \(error.localizedDescription)")
        }
    }

    private func use(_ calibration: CaseCalibration) {
        var next = CaseInputProcessor(calibration: calibration, pointerConfiguration: pointerConfiguration)
        next.tapSensitivity = tapSensitivity
        next.multiTapWindow = multiTapWindow
        processor = next
        isCalibrated = true
        hasWarnedAboutSensor = false
        targetPoint = .center
        shownPoint = .center
    }

    private func save(_ calibration: CaseCalibration) {
        if let data = try? JSONEncoder().encode(calibration) {
            UserDefaults.standard.set(data, forKey: Self.calibrationKey)
        }
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.rangeKey) != nil {
            pointerConfiguration.rangeDegrees = defaults.double(forKey: Self.rangeKey)
        }
        if defaults.object(forKey: Self.steadinessKey) != nil {
            pointerConfiguration.minCutoff = defaults.double(forKey: Self.steadinessKey)
        }
        pointerConfiguration.invertHorizontal = defaults.bool(forKey: Self.invertHorizontalKey)
        pointerConfiguration.invertVertical = defaults.bool(forKey: Self.invertVerticalKey)
        if defaults.object(forKey: Self.sensitivityKey) != nil {
            tapSensitivity = defaults.double(forKey: Self.sensitivityKey)
        }
        if defaults.object(forKey: Self.multiTapKey) != nil {
            multiTapWindow = defaults.double(forKey: Self.multiTapKey)
        }
    }

    private func loadCalibration() {
        guard let data = UserDefaults.standard.data(forKey: Self.calibrationKey),
              let saved = try? JSONDecoder().decode(CaseCalibration.self, from: data) else { return }
        use(saved)
        addLog("Loaded saved calibration")
    }

    private func addTimer(interval: TimeInterval, _ action: @escaping @MainActor (AppModel) -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers.append(timer)
    }

    private func addLog(_ message: String) {
        log.append("\(Self.timeFormat.string(from: Date())) \(message)")
        if log.count > Self.maxLogLines {
            log.removeFirst(log.count - Self.maxLogLines)
        }
    }

    private static var now: Double { ProcessInfo.processInfo.systemUptime }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
