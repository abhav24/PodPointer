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
