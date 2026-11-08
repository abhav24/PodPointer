import Foundation

/// One Euro filter (Casiez et al., CHI 2012). It smooths heavily at low speed to
/// remove hand tremor, and lightly at high speed to keep lag low.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var lastValue: Double?
    private var lastDerivative = 0.0
    private var lastTime = 0.0

    public init(minCutoff: Double, beta: Double, derivativeCutoff: Double = 1) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func filter(_ value: Double, at time: Double) -> Double {
        guard let previous = lastValue else {
            lastValue = value
            lastTime = time
            return value
        }
        let elapsed = time - lastTime
        guard elapsed > 0 else { return previous }

        let derivative = (value - previous) / elapsed
        let smoothedDerivative = Self.blend(derivative, lastDerivative, cutoff: derivativeCutoff, elapsed: elapsed)
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let filtered = Self.blend(value, previous, cutoff: cutoff, elapsed: elapsed)

        lastValue = filtered
        lastDerivative = smoothedDerivative
        lastTime = time
        return filtered
    }

    public mutating func reset() {
        lastValue = nil
        lastDerivative = 0
    }

    private static func blend(_ value: Double, _ previous: Double, cutoff: Double, elapsed: Double) -> Double {
        let timeConstant = 1 / (2 * Double.pi * cutoff)
        let alpha = 1 / (1 + timeConstant / elapsed)
        return alpha * value + (1 - alpha) * previous
    }
}
