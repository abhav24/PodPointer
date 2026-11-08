import AppKit
import SwiftUI

@main
struct PodPointerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("PodPointer", id: "main") {
            RootView(model: model)
                .onAppear { model.start() }
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            switch model.stage {
            case .welcome:
                WelcomePage(model: model)
            case .caseCheck:
                CaseCheckPage(model: model)
            case .allowControl:
                AllowControlPage(model: model)
            case .trySlides:
                TrySlidesPage(model: model)
            case .home:
                HomeView(model: model)
            }
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 620, idealHeight: 720)
        .tint(.indigo)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            model.refreshDisplays()
        }
    }
}
