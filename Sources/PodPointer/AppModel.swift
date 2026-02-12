import AppKit
import PodPointerCore
import SwiftUI

enum PointerMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case laser = "Laser dot"
    case cursor = "Mouse cursor"

