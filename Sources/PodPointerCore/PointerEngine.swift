import Foundation

/// A position on a display, from 0 to 1. (0, 0) is the top-left corner.
public struct PointerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public static let center = PointerPoint(x: 0.5, y: 0.5)

