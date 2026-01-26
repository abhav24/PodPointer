import Testing
@testable import PodPointerCore

@Suite struct OneEuroFilterTests {
    @Test func firstSamplePassesThrough() {
        var filter = OneEuroFilter()
        #expect(filter.filter(5, at: 0) == 5)
    }

    @Test func reducesJitterAroundAStillValue() {
