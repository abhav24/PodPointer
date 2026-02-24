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
            motionSection
            stemSection
            pointerSection
            logSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 620, idealHeight: 820)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            model.refreshDisplays()
        }
    }

    private var motionSection: some View {
        Section("1. Motion") {
            LabeledContent("Motion permission", value: model.permission)
            LabeledContent("AirPods", value: model.isConnected ? "Connected" : "Not connected")
            LabeledContent("Samples", value: model.isStale ? "Not arriving" : "Arriving")
            LabeledContent("Rate", value: String(format: "%.1f Hz", model.rate.hertz))
            LabeledContent("p95 interval", value: String(format: "%.0f ms", model.rate.p95IntervalMilliseconds))
            LabeledContent("Longest gap", value: String(format: "%.0f ms", model.rate.maxGapMilliseconds))
            LabeledContent("Sensor", value: model.sensorLocation)
            LabeledContent("Orientation", value: model.attitude)
        }
    }

    private var stemSection: some View {
        Section {
            Toggle("Listen for stem presses", isOn: Binding(
                get: { model.isListeningForStem },
                set: { model.setListeningForStem($0) }
            ))
            Toggle("Send arrow keys to the front app", isOn: $model.sendsSlideKeys)
            if !model.hasAccessibility {
                LabeledContent("Sending keys needs Accessibility access") {
                    Button("Open Prompt") { model.requestAccessibility() }
                }
            }
            LabeledContent(
                "Presses received",
                value: StemPress.allCases.map { "\($0.rawValue) \(model.pressCounts[$0, default: 0])" }.joined(separator: " · ")
            )
        } header: {
            Text("2. Stem presses")
        } footer: {
            Text("Single: next slide. Double: recenter. Triple: previous slide.")
        }
    }

    private var pointerSection: some View {
        Section {
            Picker("Pointer", selection: Binding(
                get: { model.pointerMode },
                set: { model.setPointerMode($0) }
            )) {
                ForEach(PointerMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Display", selection: $model.selectedDisplayID) {
                ForEach(model.displays) { Text($0.name).tag($0.id) }
            }
            Button("Recenter") { model.recenter() }
            Slider(value: $model.configuration.horizontalRangeDegrees, in: 10...80) {
                Text("Turn range: \(Int(model.configuration.horizontalRangeDegrees))°")
            }
            Slider(value: $model.configuration.verticalRangeDegrees, in: 10...60) {
                Text("Tilt range: \(Int(model.configuration.verticalRangeDegrees))°")
            }
            Slider(value: $model.configuration.minCutoff, in: 0.3...5) {
                Text(String(format: "Filter cutoff: %.1f Hz", model.configuration.minCutoff))
            }
            Toggle("Invert left and right", isOn: $model.configuration.invertX)
            Toggle("Invert up and down", isOn: $model.configuration.invertY)
        } header: {
            Text("3. Pointer")
        } footer: {
            Text("Look at the middle of the display, then recenter. Moving a real mouse turns off cursor control. A lower filter cutoff is steadier but lags more.")
        }
    }

    private var logSection: some View {
        Section {
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
        } header: {
            Text("Log")
        }
    }
}
