import Foundation

/// One Euro filter (Casiez et al., CHI 2012): smooths heavily when the input is
/// slow, which removes jitter, and lightly when it is fast, which reduces lag.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var lastFiltered: Double?
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
        let elapsed = time - previousTime
        guard elapsed > 0 else { return previous }

        let derivative = (value - previous) / elapsed
        let derivativeAlpha = Self.alpha(cutoff: derivativeCutoff, elapsed: elapsed)
        let smoothedDerivative = derivativeAlpha * derivative + (1 - derivativeAlpha) * lastDerivative

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
