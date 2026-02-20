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
