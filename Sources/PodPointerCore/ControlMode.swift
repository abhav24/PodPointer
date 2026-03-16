import Foundation

public enum ControlMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case presenter = "Presenter"
    case mouse = "Mouse"

    public var id: String { rawValue }
}

public enum CaseAction: String, Equatable, Sendable {
    case nextSlide = "next slide"
    case previousSlide = "previous slide"
    case click = "click"
    case doubleClick = "double-click"
    case togglePointer = "pointer on or off"

