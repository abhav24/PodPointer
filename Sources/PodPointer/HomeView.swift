import PodPointerCore
import SwiftUI

/// The everyday screen after setup.
struct HomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            controlSection
            if !model.hasAccessibility {
                accessSection
            }
            if !model.isReceivingMotion {
                connectionSection
            }
            calibrationSection
            advancedSection
        }
        .formStyle(.grouped)
    }

    private var controlSection: some View {
        Section {
            Picker("Mode", selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(ControlMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(!model.canUsePointer)

            switch model.mode {
            case .off:
                Text("Choose Presenter to control slides, or Mouse to control your Mac.")
                    .foregroundStyle(.secondary)
            case .presenter:
                control("Rotate", "Moves the laser dot")
                control("Tap", "Next slide")
                control("Double-tap", "Previous slide")
                control("Triple-tap", "Turns the dot on or off")
            case .mouse:
                control("Rotate", "Moves the cursor")
                control("Tap", "Click")
                control("Double-tap", "Double-click")
                control("Triple-tap", "Pauses or resumes the cursor")
                Text("Moving a real mouse or trackpad pauses the case until you stop.")
                    .foregroundStyle(.secondary)
            }
            if model.displays.count > 1 {
                Picker("Display", selection: $model.selectedDisplayID) {
                    ForEach(model.displays) { Text($0.name).tag($0.id) }
                }
            }
            Button("Recenter Pointer") { model.recenter() }
                .disabled(!model.canUsePointer)
        } header: {
            Text("Control")
        } footer: {
            Text("Keep the case lid open and Automatic Ear Detection off while you use PodPointer.")
        }
    }

    private var accessSection: some View {
        Section("Taps can't control your Mac yet") {
            Text("To change slides and click, turn on PodPointer in the list that System Settings opens.")
            Button("Allow Access") { model.requestAccessibility() }
        }
    }

    private var connectionSection: some View {
        Section("Your AirPods aren't sending motion") {
            Text("Connect your AirPods to this Mac and open the case lid. Check that Automatic Ear Detection is off in Bluetooth settings.")
            Button("Open Bluetooth Settings") { model.openBluetoothSettings() }
        }
    }

    private var calibrationSection: some View {
        Section {
            if let step = model.calibrationStep {
                Text(calibrationInstruction(for: step))
                    .font(.headline)
                ProgressView(value: model.calibrationProgress)
                Button("Cancel") { model.cancelCalibration() }
            } else {
                Button("Calibrate Again") { model.startCalibration() }
            }
            if let message = model.calibrationMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Calibration")
        } footer: {
            Text("Calibrate again if you change how you hold the case.")
        }
    }

    private var advancedSection: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $model.showsAdvanced) {
                Slider(value: $model.pointerConfiguration.rangeDegrees, in: 15...90) {
                    Text("Pointer range: \(Int(model.pointerConfiguration.rangeDegrees))°")
                }
                Slider(value: $model.pointerConfiguration.minCutoff, in: 0.3...5) {
                    Text(String(format: "Steadiness: %.1f Hz", model.pointerConfiguration.minCutoff))
                }
                Slider(value: $model.tapSensitivity, in: 0.5...2) {
                    Text(String(format: "Tap sensitivity: %.1f×", model.tapSensitivity))
                }
                Slider(value: $model.multiTapWindow, in: 0.25...0.7) {
                    Text(String(format: "Time between taps: %.2f s", model.multiTapWindow))
                }
                Toggle("Flip up and down", isOn: $model.pointerConfiguration.invertVertical)
                Toggle("Flip left and right", isOn: $model.pointerConfiguration.invertHorizontal)
                Toggle("Send keys and clicks", isOn: $model.sendsActions)
                Toggle("Keep audio connection active", isOn: $model.keepsAudioActive)
                LabeledContent("AirPods", value: model.isConnected ? "Connected" : "Not connected")
                LabeledContent("Motion", value: model.isReceivingMotion ? "Arriving" : "Not arriving")
                LabeledContent("Rate", value: String(format: "%.0f Hz", model.rate.hertz))
                LabeledContent("Longest gap", value: String(format: "%.0f ms", model.rate.longestGapMilliseconds))
                LabeledContent("Sending AirPod", value: model.sensorLocation)
                LabeledContent("Jolt", value: String(format: "%.2f g", model.strongestJolt))
                LabeledContent(
                    "Taps detected",
                    value: CaseGesture.allCases.map { "\($0.rawValue) \(model.gestureCounts[$0, default: 0])" }.joined(separator: " · ")
                )
                logView
                HStack {
                    Button("Copy Test Report") { model.copyReport() }
                    Button("Show Motion Recording") { model.showRecordingInFinder() }
                    Button("Run Setup Again") { model.startOver() }
                }
            }
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
            }
            .frame(height: 120)
            .onChange(of: model.log.count) { _, count in
                proxy.scrollTo(count - 1, anchor: .bottom)
            }
        }
    }

    private func control(_ gesture: String, _ action: String) -> some View {
        LabeledContent(gesture, value: action)
    }

    private func calibrationInstruction(for step: CalibrationStep) -> String {
        if model.calibrationIsSettling { return "Hold still for a moment." }
        switch step {
        case .holdStill:
            return "Hold the case still."
        case .sweepSideways:
            return "Sweep smoothly side to side."
        case .turnRight:
            return "Turn the case right, then stop."
        case .sweepVertically:
            return "Sweep smoothly up and down."
        case .turnUp:
            return "Tilt the case up, then stop."
        case .tap:
            return "Hold still and tap \(CalibrationSession.requiredTaps) times (\(model.calibrationTaps) so far)."
        }
    }
}
