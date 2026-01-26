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
