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

@Suite struct CalibrationTests {
    /// Feeds a full calibration, with the case held at an arbitrary angle.
    private func run(
        horizontal: Vector3,
        vertical: Vector3,
        bias: Vector3 = .zero,
        tapStrength: Double = 0.8
    ) -> CalibrationStatus {
        var session = CalibrationSession(sensorLocation: "right")
        var time = 0.0
        var status = CalibrationStatus.inProgress

        func feed(_ next: MotionReading) {
            if case .inProgress = status {
                status = session.process(next)
            }
            time += sampleInterval
        }

        while session.step == .holdStill, status == .inProgress {
            feed(reading(rotation: bias, at: time))
        }
        for step in [(CalibrationStep.sweepSideways, horizontal), (.sweepVertically, vertical)] {
            let start = time
            while session.step == step.0, status == .inProgress {
                // Starts in the positive direction, then sweeps back and forth.
                let wave = sin((time - start) * 2 * .pi * 0.75)
                feed(reading(rotation: bias + step.1 * (wave * 1.5), at: time))
            }
        }
        var tapClock = 0
        while status == .inProgress, time < 60 {
            let jolt = tapClock % 25 == 0 ? Vector3(x: tapStrength, y: 0, z: 0) : .zero
            feed(reading(rotation: bias, acceleration: jolt, at: time))
            tapClock += 1
        }
        return status
    }

    @Test func learnsAxesForAnyGrip() throws {
        let horizontal = Vector3(x: 1, y: 2, z: -1).normalized
        let raw = Vector3(x: 2, y: -1, z: 1).normalized
        let status = run(horizontal: horizontal, vertical: raw)

        guard case let .finished(result) = status else {
            Issue.record("Expected calibration to finish, got \(status)")
            return
        }
        #expect(result.horizontalAxis.dot(horizontal) > 0.99)
        #expect(result.verticalAxis.dot(raw) > 0.9)
        #expect(abs(result.horizontalAxis.dot(result.verticalAxis)) < 0.01)
        #expect(result.sensorLocation == "right")
    }

    @Test func measuresGyroBiasAndTapThreshold() {
        let bias = Vector3(x: 0.02, y: -0.01, z: 0.03)
        let status = run(horizontal: Vector3(x: 0, y: 0, z: 1), vertical: Vector3(x: 1, y: 0, z: 0), bias: bias)

        guard case let .finished(result) = status else {
            Issue.record("Expected calibration to finish, got \(status)")
            return
        }
        #expect((result.gyroBias - bias).magnitude < 0.001)
        #expect(abs(result.tapThreshold - 0.48) < 0.01)
    }

    @Test func rejectsTwoSweepsAroundTheSameAxis() {
        let axis = Vector3(x: 0, y: 1, z: 0)
        #expect(run(horizontal: axis, vertical: axis) == .failed(.axesTooSimilar))
    }

    @Test func rejectsWhenThereIsNoSweep() {
        #expect(run(horizontal: .zero, vertical: .zero) == .failed(.tooLittleMovement))
    }

    @Test func rejectsWhenThereAreNoTaps() {
        let status = run(horizontal: Vector3(x: 0, y: 0, z: 1), vertical: Vector3(x: 1, y: 0, z: 0), tapStrength: 0)
        #expect(status == .failed(.tooFewTaps))
    }

    @Test func movingDuringHoldRestartsIt() {
        var session = CalibrationSession(sensorLocation: "left")
        var time = 0.0
        for _ in 0..<90 {
            _ = session.process(reading(at: time))
            time += sampleInterval
        }
        _ = session.process(reading(rotation: Vector3(x: 2, y: 0, z: 0), at: time))
        #expect(session.step == .holdStill)
        #expect(session.progress == 0)
    }

    @Test func slowMotionStreamFails() {
        var session = CalibrationSession(sensorLocation: "left")
        var status = CalibrationStatus.inProgress
        for second in 0..<4 {
            status = session.process(reading(at: Double(second)))
        }
        #expect(status == .failed(.tooFewSamples))
    }
}

@Suite struct TapDetectorTests {
    private func events(_ acceleration: [Double], rotation: Double = 0, threshold: Double = 0.3) -> [TapDetector.Event] {
        var detector = TapDetector(threshold: threshold)
        return acceleration.enumerated().map { index, value in
            detector.process(
                acceleration: Vector3(x: value, y: 0, z: 0),
                rotationSpeed: rotation,
                at: Double(index) * sampleInterval
            )
        }
    }

    @Test func aShortJoltIsATap() {
        let result = events(Array(repeating: 0, count: 20) + [1, 1] + Array(repeating: 1, count: 5))
        #expect(result.contains(.impulseStarted))
        #expect(result.contains(.tap))
    }

    @Test func smallChangesAreIgnored() {
        let result = events((0..<60).map { $0.isMultiple(of: 2) ? 0.05 : 0 })
        #expect(result.allSatisfy { $0 == .none })
    }

    @Test func aTapWhilePointingIsIgnored() {
        let result = events(Array(repeating: 0, count: 20) + [1, 1, 1, 1], rotation: 2)
        #expect(result.allSatisfy { $0 == .none })
    }

    @Test func aLongShakeIsRejected() {
        let shake = (0..<30).map { $0.isMultiple(of: 2) ? 1.0 : 0.0 }
        let result = events(Array(repeating: 0, count: 20) + shake)
        #expect(result.contains(.rejected))
        #expect(!result.contains(.tap))
    }

    @Test func twoQuickTapsBothCount() {
        var detector = TapDetector(threshold: 0.3)
        var taps = 0
        for index in 0..<100 {
            let time = Double(index) * sampleInterval
            let jolt = index == 30 || index == 45
            // The tap also shakes the gyroscope, which must not block the next tap.
            let event = detector.process(
                acceleration: Vector3(x: jolt ? 1 : 0, y: 0, z: 0),
                rotationSpeed: (31...34).contains(index) ? 3 : 0,
                at: time
            )
            if event == .tap { taps += 1 }
        }
        #expect(taps == 2)
    }
}

@Suite struct TapSequenceTests {
    @Test func singleWaitsForTheWindow() {
        var sequence = TapSequence(windowSeconds: 0.35)
        #expect(sequence.registerTap(at: 1) == nil)
        #expect(sequence.poll(at: 1.2) == nil)
        #expect(sequence.poll(at: 1.4) == .single)
        #expect(sequence.poll(at: 2) == nil)
    }

    @Test func doubleAndTriple() {
        var sequence = TapSequence(windowSeconds: 0.35)
        _ = sequence.registerTap(at: 1)
        _ = sequence.registerTap(at: 1.2)
        #expect(sequence.poll(at: 1.6) == .double)

        _ = sequence.registerTap(at: 3)
        _ = sequence.registerTap(at: 3.2)
        #expect(sequence.registerTap(at: 3.4) == .triple)
    }
}

@Suite struct PointerEngineTests {
    private func sweep(
        _ engine: inout PointerEngine,
        horizontal: Double = 0,
        vertical: Double = 0,
        seconds: Double,
        from start: Double = 0
    ) -> PointerPoint {
        var point = engine.position
        var time = start
        while time <= start + seconds {
            point = engine.advance(horizontalRate: horizontal, verticalRate: vertical, at: time)
            time += sampleInterval
        }
        return point
    }

    private func engine() -> PointerEngine {
        var configuration = PointerConfiguration()
        configuration.maximumAcceleration = 1
        configuration.deadZoneDegreesPerSecond = 0
        return PointerEngine(configuration: configuration)
    }

    @Test func rotatingRightAndUpMovesRightAndUp() {
        var pointer = engine()
        let point = sweep(&pointer, horizontal: 10, vertical: 5, seconds: 1)
        #expect(point.x > 0.6)
        #expect(point.y < 0.45)
    }

    @Test func fullRangeCrossesTheDisplay() {
        var pointer = engine()
        pointer.set(position: PointerPoint(x: 0, y: 0.5))
        _ = sweep(&pointer, horizontal: 40, seconds: 1)
        _ = sweep(&pointer, seconds: 1, from: 1.02)
        #expect(abs(pointer.position.x - 1) < 0.03)
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
