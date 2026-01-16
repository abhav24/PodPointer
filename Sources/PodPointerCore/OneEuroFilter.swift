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
