import Foundation

/// A stem press, as macOS reports it through its media-control commands.
public enum StemPress: String, CaseIterable, Sendable {
    case single
    case double
    case triple
}
