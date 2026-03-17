import Foundation

/// One Euro filter (Casiez et al., CHI 2012). It smooths heavily at low speed to
/// remove hand tremor, and lightly at high speed to keep lag low.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var lastValue: Double?
    private var lastDerivative = 0.0
    private var lastTime: Double?

    public init(minCutoff: Double = 1.0, beta: Double = 0.05, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func filter(_ value: Double, at time: Double) -> Double {
        guard let previous = lastFiltered, let previousTime = lastTime else {
            lastFiltered = value
            lastTime = time
            return value
        }
        let elapsed = time - lastTime
        guard elapsed > 0 else { return previous }

        let derivative = (value - previous) / elapsed
        let smoothedDerivative = Self.blend(derivative, lastDerivative, cutoff: derivativeCutoff, elapsed: elapsed)
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let filtered = Self.blend(value, previous, cutoff: cutoff, elapsed: elapsed)

        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let valueAlpha = Self.alpha(cutoff: cutoff, elapsed: elapsed)
        let filtered = valueAlpha * value + (1 - valueAlpha) * previous

        lastFiltered = filtered
        lastDerivative = smoothedDerivative
        lastTime = time
        return filtered
    }

    public mutating func reset() {
        lastFiltered = nil
        lastDerivative = 0
        lastTime = nil
    }

    private static func alpha(cutoff: Double, elapsed: Double) -> Double {
        let timeConstant = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + timeConstant / elapsed)
    }
}
