import Testing
@testable import PodPointerCore

@Suite struct OneEuroFilterTests {
    @Test func firstSamplePassesThrough() {
        var filter = OneEuroFilter()
        #expect(filter.filter(5, at: 0) == 5)
    }

    @Test func reducesJitterAroundAStillValue() {
        var filter = OneEuroFilter()
        var outputs: [Double] = []
        for index in 0..<200 {
            let noisy = index.isMultiple(of: 2) ? 10.5 : 9.5
            outputs.append(filter.filter(noisy, at: Double(index) / 25))
        }
        let settled = outputs.suffix(50)
        let spread = (settled.max() ?? 0) - (settled.min() ?? 0)
        #expect(spread < 0.5)
    }

    @Test func convergesOnAStep() {
        var filter = OneEuroFilter()
        _ = filter.filter(0, at: 0)
        var output = 0.0
        for index in 1...100 {
            output = filter.filter(10, at: Double(index) / 25)
        }
        #expect(abs(output - 10) < 0.05)
    }

    @Test func repeatedTimestampKeepsThePreviousValue() {
        var filter = OneEuroFilter()
        _ = filter.filter(1, at: 1)
        #expect(filter.filter(100, at: 1) == 1)
    }
}

@Suite struct PointerMapperTests {
    private let degree = Double.pi / 180

    /// Feeds one orientation repeatedly so the filter settles on it.
    private func settle(_ mapper: inout PointerMapper, yaw: Double, pitch: Double, from start: Double = 1) -> PointerPoint {
        var point = PointerPoint(x: 0, y: 0)
        for index in 0..<200 {
            point = mapper.map(yawRadians: yaw, pitchRadians: pitch, at: start + Double(index) / 25)
        }
        return point
    }

