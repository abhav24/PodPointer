import AppKit
import PodPointerCore
import SwiftUI

enum PointerMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case laser = "Laser dot"
    case cursor = "Mouse cursor"

    var id: String { rawValue }
}

struct DisplayOption: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

@MainActor
final class AppModel: ObservableObject {
    static let version = "0.1.0"
    private static let staleSampleSeconds = 0.5
    private static let maxLogLines = 200
    private static let cursorGraceSeconds = 2.0

    // Motion
    @Published private(set) var permission = "Not asked yet"
    @Published private(set) var isConnected = false
    @Published private(set) var rate = SampleRateSnapshot.empty
    @Published private(set) var sensorLocation = "-"
    @Published private(set) var attitude = "-"
    @Published private(set) var isStale = true

    // Pointer
    @Published private(set) var pointerMode = PointerMode.off
    @Published private(set) var displays: [DisplayOption] = []
    @Published var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID() {
        didSet { showOverlayIfNeeded() }
    }
    @Published var configuration = PointerConfiguration() {
        didSet { mapper.configuration = configuration }
    }

    // Stem presses
    @Published private(set) var isListeningForStem = false
    @Published var sendsSlideKeys = false
    @Published private(set) var hasAccessibility = KeySender.isTrusted
    @Published private(set) var pressCounts: [StemPress: Int] = [:]

