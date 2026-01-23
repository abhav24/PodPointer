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
        case .double: self = .recenter
        case .triple: self = .previousSlide
        }
    }
}

/// Collapses repeats of one press. A single press can arrive as more than one
/// media command, such as play and toggle-play-pause.
public struct StemPressDebouncer: Sendable {
    public let windowSeconds: Double
    private var lastPress: StemPress?
    private var lastTime = -Double.infinity

    public init(windowSeconds: Double = 0.15) {
        self.windowSeconds = windowSeconds
    }

    public mutating func shouldAccept(_ press: StemPress, at time: Double) -> Bool {
        if press == lastPress, time - lastTime < windowSeconds {
            return false
        }
        lastPress = press
        lastTime = time
        return true
    }
}
