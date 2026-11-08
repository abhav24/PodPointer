import AppKit
import PodPointerCore
import SwiftUI

@main
struct PodPointerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("PodPointer", id: "main") {
            ContentView(model: model)
                .onAppear { model.start() }
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            setupSection
            calibrationSection
            controlSection
            tuningSection
            logSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 620, idealHeight: 820)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            model.refreshDisplays()
        }
    }

    private var setupSection: some View {
        Section {
            LabeledContent("Motion permission", value: model.permission)
            LabeledContent("AirPods", value: model.isConnected ? "Connected" : "Not connected")
            LabeledContent("Motion", value: model.isReceivingMotion ? "Arriving" : "Not arriving")
            LabeledContent("Rate", value: String(format: "%.0f Hz", model.rate.hertz))
            LabeledContent("Longest gap", value: String(format: "%.0f ms", model.rate.longestGapMilliseconds))
            LabeledContent("Sending AirPod", value: model.sensorLocation)
            LabeledContent("Jolt", value: String(format: "%.2f g", model.strongestJolt))
            Toggle("Keep audio connection active", isOn: $model.keepsAudioActive)
        } header: {
            Text("1. Set up the case")
        } footer: {
            Text("Connect your AirPods and select them as the sound output. Turn off Automatic Ear Detection in System Settings, put the AirPods in the case, and keep the lid open. If motion doesn't arrive, try keeping the audio connection active.")
        }
    }

    private var calibrationSection: some View {
        Section {
            if let step = model.calibrationStep {
                Text(instruction(for: step))
                    .font(.headline)
                ProgressView(value: model.calibrationProgress)
                Button("Cancel") { model.cancelCalibration() }
            } else {
                LabeledContent("Status", value: model.isCalibrated ? "Calibrated" : "Not calibrated")
                Button(model.isCalibrated ? "Calibrate Again" : "Calibrate") { model.startCalibration() }
            }
            if let message = model.calibrationMessage {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("2. Calibrate")
        } footer: {
            Text("Hold the case the way you'll use it. Calibrate again if you change your grip.")
        }
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

            Picker("Display", selection: $model.selectedDisplayID) {
                ForEach(model.displays) { Text($0.name).tag($0.id) }
            }
            Button("Recenter") { model.recenter() }
                .disabled(!model.canUsePointer)
            Toggle("Send keys and clicks", isOn: $model.sendsActions)
            if !model.hasAccessibility {
                LabeledContent("Sending needs Accessibility access") {
                    Button("Open Prompt") { model.requestAccessibility() }
                }
            }
            LabeledContent(
                "Taps detected",
                value: CaseGesture.allCases.map { "\($0.rawValue) \(model.gestureCounts[$0, default: 0])" }.joined(separator: " · ")
            )
        } header: {
            Text("3. Control")
        } footer: {
            Text("Presenter: laser dot. Tap for the next slide, double-tap for the previous one.\nMouse: moves the cursor. Tap to click, double-tap to double-click.\nTriple-tap turns the pointer on or off. Moving a real mouse pauses Mouse mode.")
        }
    }

    private var tuningSection: some View {
        Section("Adjust") {
            Slider(value: $model.pointerConfiguration.rangeDegrees, in: 15...90) {
                Text("Range: \(Int(model.pointerConfiguration.rangeDegrees))°")
            }
            Slider(value: $model.pointerConfiguration.minCutoff, in: 0.3...5) {
                Text(String(format: "Steadiness: %.1f Hz", model.pointerConfiguration.minCutoff))
            }
            Slider(value: $model.tapSensitivity, in: 0.5...2) {
                Text(String(format: "Tap sensitivity: %.1f×", model.tapSensitivity))
            }
        }
    }

    private var logSection: some View {
        Section("Log") {
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
                .frame(height: 140)
                .onChange(of: model.log.count) { _, count in
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
            Button("Copy Test Report") { model.copyReport() }
        }
    }

    private func instruction(for step: CalibrationStep) -> String {
        switch step {
        case .holdStill:
            "Hold the case still."
        case .sweepSideways:
            "Sweep it right first, then left and right."
        case .sweepVertically:
            "Sweep it up first, then down and up."
        case .tap:
            "Hold still and tap the case \(CalibrationSession.requiredTaps) times (\(model.calibrationTaps) so far)."
        }
    }
}
