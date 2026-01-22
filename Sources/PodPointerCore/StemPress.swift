import Foundation

/// A stem press, as macOS reports it through its media-control commands.
public enum StemPress: String, CaseIterable, Sendable {
    case single
    case double
    case triple
}

public enum StemAction: String, Sendable {
    case nextSlide = "Next slide"
    case recenter = "Recenter pointer"
    case previousSlide = "Previous slide"

    public init(press: StemPress) {
        switch press {
        case .single: self = .nextSlide
