import Foundation

public enum ControlMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case presenter = "Presenter"
    case mouse = "Mouse"

    public var id: String { rawValue }
}

public enum CaseAction: String, Equatable, Sendable {
