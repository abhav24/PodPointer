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
