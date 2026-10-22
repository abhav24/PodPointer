import PodPointerCore
import SwiftUI

/// The shared layout for each page of setup.
struct SetupPage<Content: View>: View {
    static var stepCount: Int { 10 }

    var step: Int?
    var heading: String?
    let symbol: String
    let title: String
    var detail: String?
    var onStartOver: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let step {
                    VStack(spacing: 8) {
                        Text("Step \(step) of \(Self.stepCount)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        ProgressView(value: Double(step), total: Double(Self.stepCount))
                            .frame(maxWidth: 220)
                    }
                } else if let heading {
                    Text(heading)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: symbol)
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .frame(height: 68)
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
        .safeAreaInset(edge: .bottom) {
            if let onStartOver {
                Button("Start Over", action: onStartOver)
                    .buttonStyle(.link)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
    }
}

/// A soft rounded panel that groups related content on a page.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Numbered instructions.
struct InstructionList: View {
    let items: [String]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(.tint, in: Circle())
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 180)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
}

/// Shows what the app is waiting for, so a still screen doesn't look stuck.
struct WaitingLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

struct WelcomePage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SetupPage(
            symbol: "airpodspro.chargingcase.wireless",
            title: "Turn your AirPods case into a remote",
            detail: "Point the case at your screen and tap it to control your slides or your Mac."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                feature("scope", "Rotate the case to move a laser dot or your cursor.")
                feature("hand.tap", "Tap the case to change slides or click.")
                feature("checkmark.seal", "Setup takes about 6 minutes and tests that it works.")
            }
            Text("You'll need your AirPods and their case. PodPointer will ask to use motion data from your AirPods. That data stays on this Mac.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Get Started") { model.beginSetup() }
        }
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
        }
    }
}

struct CaseCheckPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let check = model.check {
            page(for: check)
        }
    }

    @ViewBuilder
    private func page(for check: CaseCheck) -> some View {
        switch check.step {
        case .connect:
            connect
        case .earDetection:
            earDetection
        case .placeInCase:
            page(3, symbol: "airpodspro.chargingcase.wireless", title: "Put your AirPods in the case") {
                InstructionList(items: [
                    "Put both AirPods in the case.",
                    "Leave the lid open. Closing it disconnects them.",
                    "Keep the case in your hand."
                ])
                PrimaryButton("They're in the Case") { model.confirmInCase() }
            }
        case .watchingCase:
            page(3, symbol: "move.3d", title: "Move the case around", detail: "Rotate it in your hand for a moment to confirm the AirPods are still sending motion.") {
                WaitingLabel(text: "Waiting for the case to move")
            }
        case .motionLost:
            motionLost
        case .calibrate:
            calibration
        case .tapTest:
            tapTest(check)
        case .gestureTest:
            gestureTest(check)
        case .moveTest:
            page(7, symbol: "hand.wave", title: "Wave the case. Don't tap it.", detail: "This checks that normal movement isn't mistaken for a tap.") {
                countdown(Int(check.moveSecondsLeft(at: model.checkClock).rounded(.up)), label: "seconds left")
                Text("Mistaken taps so far: \(check.results.falseTapsWhileMoving)")
                    .foregroundStyle(.secondary)
            }
        case .pointTest:
            page(8, symbol: "scope", title: "Aim at the green ring", detail: nil) {
                InstructionList(items: [
                    "Find the red dot and the green ring on your screen.",
                    "Rotate the case until the dot is inside the ring.",
                    "Hold still and tap the case."
                ])
                Text("Ring \(check.targetIndex + 1) of \(CaseCheck.targets.count) · Hits: \(check.results.targetsHit)")
                    .font(.headline)
                Text("If the dot reaches the edge of your screen, keep rotating to reposition your aim. Each ring moves on after 15 seconds.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Flip up and down", isOn: $model.pointerConfiguration.invertVertical)
                    .toggleStyle(.switch)
                Toggle("Flip left and right", isOn: $model.pointerConfiguration.invertHorizontal)
                    .toggleStyle(.switch)
            }
        case .results:
            results(check.results)
        }
    }

    private func page<Content: View>(
        _ number: Int,
        symbol: String,
        title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SetupPage(
            progress: "Step \(number) of 9",
            symbol: symbol,
            title: title,
            detail: detail,
            onStartOver: { model.startOver() },
            content: content
        )
    }

    private var connect: some View {
        page(1, symbol: "airpodspro", title: "Connect your AirPods") {
            if model.permission == "Denied" || model.permission == "Restricted" {
                InstructionList(items: [
                    "Select the button below to open Privacy & Security.",
                    "Open Motion & Fitness and turn on PodPointer.",
                    "Quit and reopen PodPointer."
                ])
                PrimaryButton("Open Privacy & Security") { model.openPrivacySettings() }
            } else {
                InstructionList(items: [
                    "Put both AirPods in your ears.",
                    "Connect them to this Mac, using Bluetooth settings if they don't connect by themselves.",
                    "If a message asks about motion access, select Allow."
                ])
                WaitingLabel(text: "Waiting for motion from your AirPods")
                Button("Open Bluetooth Settings") { model.openBluetoothSettings() }
                    .controlSize(.large)
            }
        }
    }

    private var earDetection: some View {
        page(2, symbol: "ear", title: "Turn off Automatic Ear Detection", detail: "With this on, AirPods stop sending motion when they leave your ears. macOS doesn't let apps change it, so you'll need to do this yourself.") {
            InstructionList(items: [
                "Keep your AirPods in your ears.",
                "Select Open Bluetooth Settings below.",
                "Click ⓘ next to your AirPods.",
                "Turn off Automatic Ear Detection, then select Done.",
                "Come back to this window."
            ])
            Button("Open Bluetooth Settings") { model.openBluetoothSettings() }
                .controlSize(.large)
            PrimaryButton("It's Off") { model.confirmEarDetectionOff() }
            Text("You can turn it back on when you finish using PodPointer.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var motionLost: some View {
        page(3, symbol: "exclamationmark.triangle", title: "Your AirPods stopped sending motion", detail: "This continues by itself as soon as motion comes back.") {
            InstructionList(items: [
                "Make sure the case lid is open.",
                "Make sure the AirPods are still connected to this Mac.",
                "Check that Automatic Ear Detection is off."
            ])
            if model.airPodsAudioFound, !model.soundUsesAirPods {
                Button("Use AirPods for Sound") { model.useAirPodsForSound() }
                    .controlSize(.large)
            }
            Toggle("Keep the audio connection active", isOn: $model.keepsAudioActive)
                .toggleStyle(.switch)
            Text("Turn this on if motion keeps stopping. It plays silence through your AirPods.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Check Ear Detection Again") { model.returnToEarDetection() }
                .controlSize(.large)
            WaitingLabel(text: "Waiting for motion")
        }
    }

    @ViewBuilder
    private var calibration: some View {
        if let step = model.calibrationStep {
            page(4, symbol: calibrationSymbol(for: step), title: calibrationTitle(for: step), detail: calibrationDetail(for: step)) {
                ProgressView(value: model.calibrationProgress)
                Text("Hold the case the way you'll use it. This teaches PodPointer your grip.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            page(4, symbol: "arrow.clockwise", title: "Let's try that again", detail: model.calibrationMessage) {
                PrimaryButton("Try Again") { model.startCalibration() }
            }
        }
    }

    private func calibrationSymbol(for step: CalibrationStep) -> String {
        if model.calibrationIsSettling { return "hand.raised" }
        switch step {
        case .holdStill: return "hand.raised"
        case .sweepSideways: return "arrow.left.and.right"
        case .turnRight: return "arrow.right"
        case .sweepVertically: return "arrow.up.and.down"
        case .turnUp: return "arrow.up"
        case .tap: return "hand.tap"
        }
    }

    private func calibrationTitle(for step: CalibrationStep) -> String {
        if model.calibrationIsSettling { return "Hold still for a moment" }
        switch step {
        case .holdStill: return "Hold the case still"
        case .sweepSideways: return "Sweep side to side"
        case .turnRight: return "Turn the case right, then stop"
        case .sweepVertically: return "Sweep up and down"
        case .turnUp: return "Tilt the case up, then stop"
        case .tap: return "Tap the case \(CalibrationSession.requiredTaps) times"
        }
    }

    private func calibrationDetail(for step: CalibrationStep) -> String {
        if model.calibrationIsSettling { return "The next instruction appears when your hand stops." }
        switch step {
        case .holdStill:
            return "Keep your hand steady for a couple of seconds."
        case .sweepSideways:
            return "Point the case at the screen, then turn your wrist smoothly left and right until this bar fills."
        case .turnRight:
            return "Turn your wrist to the right and hold it there. This shows which way is right."
        case .sweepVertically:
            return "Tilt your wrist smoothly up and down until this bar fills."
        case .turnUp:
            return "Tilt your wrist upward and hold it there. This shows which way is up."
        case .tap:
            return
            "Hold still and tap the case with a finger. Leave a short pause between taps. Taps so far: \(model.calibrationTaps)"
        }
    }

    @ViewBuilder
    private func tapTest(_ check: CaseCheck) -> some View {
        if let prompt = check.tapPromptNumber(at: model.checkClock) {
            page(5, symbol: "hand.tap", title: "Tap once now", detail: "Tap once each time the number changes, holding still in between.") {
                Text("\(prompt)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: Double(prompt), total: Double(CaseCheck.tapPrompts))
                Text("Taps counted: \(check.results.tapsHit) of \(CaseCheck.tapPrompts)")
                    .foregroundStyle(.secondary)
            }
        } else {
            page(5, symbol: "hand.tap", title: "Get ready to tap", detail: "A number will appear \(CaseCheck.tapPrompts) times. Tap the case once for each number, holding still in between.") {
                countdown(Int(check.secondsUntilTapsStart(at: model.checkClock).rounded(.up)), label: "starting in")
            }
        }
    }

    @ViewBuilder
    private func gestureTest(_ check: CaseCheck) -> some View {
        let number = "\(check.gestureIndex + 1) of \(CaseCheck.gesturePrompts.count)"
        if let prompt = check.gesturePrompt(at: model.checkClock) {
            page(6, symbol: "hand.tap", title: gestureTitle(for: prompt), detail: "Keep the taps quick and even, then hold still.") {
                gestureAnswer(check.lastGestureAnswer)
                Text("Prompt \(number) · Correct: \(check.results.gesturesHit)")
                    .foregroundStyle(.secondary)
            }
        } else {
            page(6, symbol: "hand.tap", title: "Get ready", detail: "You'll be asked for single, double, and triple taps in a mixed order.") {
                gestureAnswer(check.lastGestureAnswer)
                Text("Prompt \(number) · Correct: \(check.results.gesturesHit)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func gestureTitle(for gesture: CaseGesture) -> String {
        switch gesture {
        case .single: "Tap once"
        case .double: "Double-tap"
        case .triple: "Triple-tap"
        }
    }

    @ViewBuilder
    private func gestureAnswer(_ answer: GestureAnswer?) -> some View {
        switch answer {
        case .correct:
            Label("Correct", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .recognized(gesture):
            Label("That counted as: \(gestureTitle(for: gesture).lowercased())", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .nothing:
            Label("No taps counted", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }

    private func countdown(_ value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func results(_ results: CaseCheckResults) -> some View {
        SetupPage(
            progress: "Your results",
            symbol: results.passed ? "checkmark.seal.fill" : "slider.horizontal.3",
            title: results.passed ? "Your case works!" : "Your case needs some tuning",
            detail: results.passed ? "Next, try it with real slides." : "Adjust the settings below and run the tests again, or continue anyway.",
            onStartOver: { model.startOver() }
        ) {
            VStack(spacing: 10) {
                resultRow("Taps detected", value: "\(results.tapsHit) of \(results.tapsAsked)", passed: results.tapsPassed)
                resultRow("Single, double, triple", value: "\(results.gesturesHit) of \(results.gesturesAsked)", passed: results.gesturesPassed)
                resultRow("Mistaken taps", value: "\(results.falseTapsWhileMoving + results.extraTaps)", passed: results.movingPassed && results.extraTaps <= 1)
                resultRow("Rings hit", value: "\(results.targetsHit) of \(results.targetsAsked)", passed: results.pointingPassed)
            }
            if !results.tapsPassed {
                slider(
                    "Tap sensitivity: \(String(format: "%.1f", model.tapSensitivity))×",
                    tip: results.tapsHit < 8 ? "Too few taps counted, so try moving this right." : "Too many taps counted, so try moving this left.",
                    value: $model.tapSensitivity,
                    range: 0.5...2
                )
            } else if !results.movingPassed {
                slider(
                    "Tap sensitivity: \(String(format: "%.1f", model.tapSensitivity))×",
                    tip: "Movement counted as tapping, so try moving this left.",
                    value: $model.tapSensitivity,
                    range: 0.5...2
                )
            }
            if !results.gesturesPassed {
                slider(
                    "Time between taps: \(String(format: "%.2f", model.multiTapWindow)) seconds",
                    tip: "If double taps count as single taps, move this right. A single tap waits this long before acting.",
                    value: $model.multiTapWindow,
                    range: 0.25...0.7
                )
            }
            if !results.pointingPassed {
                slider(
                    "Pointer range: \(Int(model.pointerConfiguration.rangeDegrees))°",
                    tip: "Move this right for finer aim, or left to cover the screen with less movement.",
                    value: $model.pointerConfiguration.rangeDegrees,
                    range: 15...90
                )
            }
            HStack {
                if !results.passed {
                    Button("Run Tests Again") { model.runTestsAgain() }
                        .controlSize(.large)
                }
                PrimaryButton(results.passed ? "Try It with Slides" : "Continue") { model.continueToSlides() }
            }
        }
    }

    private func resultRow(_ title: String, value: String, passed: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Label(value, systemImage: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(passed ? .green : .orange)
        }
    }

    private func slider(_ title: String, tip: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Slider(value: value, in: range)
            Text(tip)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AllowControlPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SetupPage(
            progress: "Step 9 of 9",
            symbol: "lock.open",
            title: "Let PodPointer control your slides",
            detail: "To change slides and click, PodPointer needs Accessibility access. It only sends the arrow keys and clicks you tap for.",
            onStartOver: { model.startOver() }
        ) {
            InstructionList(items: [
                "Select Allow Access below.",
                "In the message that appears, select Open System Settings.",
                "Turn on PodPointer in the list.",
                "Come back to this window."
            ])
            PrimaryButton("Allow Access") { model.requestAccessibility() }
            WaitingLabel(text: "Waiting for access")
            Button("Skip for Now") { model.finishSetup() }
                .buttonStyle(.link)
        }
    }
}

struct TrySlidesPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SetupPage(
            progress: "Step 9 of 9",
            symbol: "play.rectangle",
            title: "Try it with real slides",
            detail: "Your case is live. The red dot follows it everywhere.",
            onStartOver: { model.startOver() }
        ) {
            InstructionList(items: [
                "Open a deck in Keynote or PowerPoint.",
                "Start the slideshow.",
                "Tap the case for the next slide, or double-tap for the previous one.",
                "Aim with the red dot. Triple-tap to turn it on or off.",
                "When you're done, leave the slideshow and come back here."
            ])
            if let lastAction = model.lastAction {
                Text("Last tap: \(lastAction)")
                    .font(.headline)
            }
            Text("Taps go to whichever app is in front, so keep your slideshow in front while you try it.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Finish Setup") { model.finishSetup() }
        }
    }
}
