import Foundation
import Testing
@testable import PodPointerCore

private let sampleInterval = 0.02
private let degree = Double.pi / 180

private func reading(
    rotation: Vector3 = .zero,
    acceleration: Vector3 = .zero,
    at time: Double
) -> MotionReading {
    MotionReading(rotationRate: rotation, userAcceleration: acceleration, timestamp: time)
}

private func isAtCenter(_ point: PointerPoint) -> Bool {
    abs(point.x - 0.5) < 1e-9 && abs(point.y - 0.5) < 1e-9
}

private func calibration(tapThreshold: Double = 0.3) -> CaseCalibration {
    CaseCalibration(
        horizontalAxis: Vector3(x: 0, y: 0, z: 1),
        verticalAxis: Vector3(x: 1, y: 0, z: 0),
        gyroBias: .zero,
        tapThreshold: tapThreshold,
        sensorLocation: "left"
    )
}

@Suite struct VectorTests {
    @Test func basicMath() {
        let vector = Vector3(x: 3, y: 4, z: 0)
        #expect(vector.magnitude == 5)
        #expect(vector.dot(Vector3(x: 1, y: 1, z: 1)) == 7)
        #expect(abs(vector.normalized.magnitude - 1) < 1e-9)
        #expect(Vector3.zero.normalized == .zero)
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

    @Test func firstSampleIsTheCenter() {
        var mapper = PointerMapper()
        #expect(mapper.map(yawRadians: 1.2, pitchRadians: -0.4, at: 0) == PointerPoint(x: 0.5, y: 0.5))
    }

    @Test func turningLeftMovesLeftAndLookingUpMovesUp() {
        var mapper = PointerMapper()
        _ = mapper.map(yawRadians: 0, pitchRadians: 0, at: 0)
        let point = settle(&mapper, yaw: 7.5 * degree, pitch: 5 * degree)
        #expect(abs(point.x - 0.25) < 0.01)
        #expect(abs(point.y - 0.25) < 0.01)
    }

    @Test func invertFlipsDirection() {
        var configuration = PointerConfiguration()
        configuration.invertX = true
        configuration.invertY = true
        var mapper = PointerMapper(configuration: configuration)
        _ = mapper.map(yawRadians: 0, pitchRadians: 0, at: 0)
        let point = settle(&mapper, yaw: 7.5 * degree, pitch: 5 * degree)
        #expect(abs(point.x - 0.75) < 0.01)
        #expect(abs(point.y - 0.75) < 0.01)
    }

    @Test func outputIsClampedToTheDisplay() {
        var mapper = PointerMapper()
        _ = mapper.map(yawRadians: 0, pitchRadians: 0, at: 0)
        let point = settle(&mapper, yaw: 90 * degree, pitch: -80 * degree)
        #expect(point.x == 0)
        #expect(point.y == 1)
    }

    @Test func crossingTheYawSeamIsASmallMove() {
        var mapper = PointerMapper()
        _ = mapper.map(yawRadians: 179 * degree, pitchRadians: 0, at: 0)
        // 179 to -179 degrees is a 2 degree left turn, not a 358 degree turn.
        let point = settle(&mapper, yaw: -179 * degree, pitch: 0)
        #expect(abs(point.x - (0.5 - 2.0 / 30)) < 0.01)
    }

    @Test func recenterMakesTheNextSampleTheCenter() {
        var mapper = PointerMapper()
        _ = mapper.map(yawRadians: 0, pitchRadians: 0, at: 0)
        _ = settle(&mapper, yaw: 40 * degree, pitch: 10 * degree)
        mapper.recenter()
        let point = mapper.map(yawRadians: 40 * degree, pitchRadians: 10 * degree, at: 20)
        #expect(point == PointerPoint(x: 0.5, y: 0.5))
    }
}

@Suite struct SampleRateTrackerTests {
    @Test func emptyUntilThereAreTwoSamples() {
        var tracker = SampleRateTracker()
        #expect(tracker.snapshot == .empty)
        tracker.record(1)
        #expect(tracker.snapshot == .empty)
    }

    @Test func measuresASteadyRate() {
        var tracker = SampleRateTracker()
        for index in 0..<50 {
            tracker.record(Double(index) * 0.04)
        }
        let snapshot = tracker.snapshot
        #expect(abs(snapshot.hertz - 25) < 0.01)
        #expect(abs(snapshot.p95IntervalMilliseconds - 40) < 0.01)
        #expect(abs(snapshot.maxGapMilliseconds - 40) < 0.01)
    }

    @Test func reportsTheLongestGap() {
        var tracker = SampleRateTracker()
        for time in [0, 0.04, 0.08, 0.58, 0.62] {
            tracker.record(time)
        }
        #expect(abs(tracker.snapshot.maxGapMilliseconds - 500) < 0.01)
    }

    @Test func dropsSamplesOutsideTheWindow() {
        var tracker = SampleRateTracker(windowSeconds: 1)
        tracker.record(0)
        tracker.record(0.5)
        tracker.record(10)
        tracker.record(10.1)
        #expect(tracker.snapshot.maxGapMilliseconds < 101)
    }
}

@Suite struct StemPressTests {
    @Test func pressesMapToSlideActions() {
        #expect(StemAction(press: .single) == .nextSlide)
        #expect(StemAction(press: .double) == .recenter)
        #expect(StemAction(press: .triple) == .previousSlide)
    }

    @Test func debouncerCollapsesRepeatsOnly() {
        var debouncer = StemPressDebouncer(windowSeconds: 0.15)
        let accepted = [
            debouncer.shouldAccept(.single, at: 1),
            debouncer.shouldAccept(.single, at: 1.1),
            debouncer.shouldAccept(.double, at: 1.12),
            debouncer.shouldAccept(.single, at: 1.14),
            debouncer.shouldAccept(.single, at: 1.5)
        ]
        #expect(accepted == [true, false, true, true, true])
    }
}

@Suite struct SessionReportTests {
    @Test func includesMeasurementsAndEvents() {
        let report = SessionReport(
            appVersion: "0.1.0",
            macOSVersion: "27.0",
            motion: SampleRateSnapshot(hertz: 25, p95IntervalMilliseconds: 41, maxGapMilliseconds: 80),
            sensorLocations: ["left"],
            pressCounts: [.single: 3],
            events: ["12:00:00 Connected"]
        ).markdown
        #expect(report.contains("Motion rate: 25.0 Hz"))
        #expect(report.contains("Sensor locations seen: left"))
        #expect(report.contains("single: 3, double: 0, triple: 0"))
        #expect(report.contains("12:00:00 Connected"))
    }
}
