import Foundation

/// A position on a display, normalized to 0...1. (0, 0) is the top-left corner.
public struct PointerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
