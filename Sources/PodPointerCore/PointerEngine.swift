import Foundation

/// A position on a display, from 0 to 1. (0, 0) is the top-left corner.
public struct PointerPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public static let center = PointerPoint(x: 0.5, y: 0.5)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Moves part of the way to a target, independent of the frame rate.
    public func eased(toward target: PointerPoint, elapsed: Double, timeConstant: Double) -> PointerPoint {
        let alpha = 1 - exp(-max(elapsed, 0) / timeConstant)
        return PointerPoint(x: x + (target.x - x) * alpha, y: y + (target.y - y) * alpha)
    }
