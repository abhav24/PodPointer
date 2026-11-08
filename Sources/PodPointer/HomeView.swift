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

