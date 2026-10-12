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
    /// `leftover` is motion that keeps going when each new step begins.
    private func run(
        horizontal: Vector3,
        vertical: Vector3,
        bias: Vector3 = .zero,
        tapStrength: Double = 0.8,
        leftover: Vector3 = .zero
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

        func settle() {
            for _ in 0..<15 where session.isSettling {
                feed(reading(rotation: bias + leftover, at: time))
            }
            while session.isSettling, status == .inProgress {
                feed(reading(rotation: bias, at: time))
            }
        }

        func sweep(_ step: CalibrationStep, around axis: Vector3) {
            settle()
            let start = time
            while session.step == step, status == .inProgress {
                let wave = sin((time - start) * 2 * .pi * 0.75)
                feed(reading(rotation: bias + axis * (wave * 1.5), at: time))
            }
        }

        func turn(_ step: CalibrationStep, around axis: Vector3) {
            settle()
            // A small wind-up the wrong way, then the real turn, then stopping.
            for _ in 0..<5 where session.step == step {
                feed(reading(rotation: bias + axis * -0.5, at: time))
            }
            for _ in 0..<30 where session.step == step {
                feed(reading(rotation: bias + axis * 1.5, at: time))
            }
            while session.step == step, status == .inProgress {
                feed(reading(rotation: bias, at: time))
            }
        }

        while session.step == .holdStill, status == .inProgress {
            feed(reading(rotation: bias, at: time))
        }
        sweep(.sweepSideways, around: horizontal)
        turn(.turnRight, around: horizontal)
        sweep(.sweepVertically, around: vertical)
        turn(.turnUp, around: vertical)
        settle()
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

    @Test func directionComesFromTheDeliberateTurn() {
        // The real-world bug: sideways motion carrying over into "sweep up".
        let horizontal = Vector3(x: 0, y: 0, z: 1)
        let vertical = Vector3(x: 1, y: 0, z: 0)
        let status = run(horizontal: horizontal, vertical: vertical, leftover: vertical * -3)
        guard case let .finished(result) = status else {
            Issue.record("Expected calibration to finish, got \(status)")
            return
        }
        #expect(result.horizontalAxis.dot(horizontal) > 0.99)
        #expect(result.verticalAxis.dot(vertical) > 0.99)
    }

    @Test func turningTheOtherWayReversesTheAxis() {
        var session = CalibrationSession(sensorLocation: "left")
        var time = 0.0
        func feed(_ rotation: Vector3) {
            _ = session.process(reading(rotation: rotation, at: time))
            time += sampleInterval
        }
        let axis = Vector3(x: 0, y: 0, z: 1)
        while session.step == .holdStill { feed(.zero) }
        while session.isSettling { feed(.zero) }
        let start = time
        while session.step == .sweepSideways {
            feed(axis * sin((time - start) * 2 * .pi * 0.75) * 1.5)
        }
        while session.isSettling { feed(.zero) }
        #expect(session.step == .turnRight)
        for _ in 0..<30 { feed(axis * -1.5) }
        feed(.zero)
        #expect(session.step == .sweepVertically)
    }

    @Test func notTurningFarEnoughFails() {
        var session = CalibrationSession(sensorLocation: "left")
        var time = 0.0
        var status = CalibrationStatus.inProgress
        let axis = Vector3(x: 0, y: 0, z: 1)
        func feed(_ rotation: Vector3) {
            status = session.process(reading(rotation: rotation, at: time))
            time += sampleInterval
        }
        while session.step == .holdStill { feed(.zero) }
        while session.isSettling { feed(.zero) }
        let start = time
        while session.step == .sweepSideways {
            feed(axis * sin((time - start) * 2 * .pi * 0.75) * 1.5)
        }
        while status == .inProgress, time < 60 { feed(.zero) }
        #expect(status == .failed(.noDirection))
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
    private func tapCount(_ acceleration: [Double], rotation: Double = 0, threshold: Double = 0.3) -> Int {
        var detector = TapDetector(threshold: threshold)
        var taps = 0
        for (index, value) in acceleration.enumerated() {
            let tap = detector.process(
                acceleration: Vector3(x: value, y: 0, z: 0),
                rotation: Vector3(x: rotation, y: 0, z: 0),
                at: Double(index) * sampleInterval
            )
            if tap != nil { taps += 1 }
        }
        return taps
    }

    /// A tap: a jolt, then shaking that fades over about 100 ms.
    private func signal(tapsAt tapSamples: [Int], length: Int = 120, strength: Double = 1) -> [Double] {
        var values = Array(repeating: 0.0, count: length)
        let ringing = [1.0, -0.8, 0.5, -0.3, 0.15, -0.08]
        for tap in tapSamples {
            for (offset, amount) in ringing.enumerated() where tap + offset < length {
                values[tap + offset] += amount * strength
            }
        }
        return values
    }

    @Test func oneTapWithRingingCountsOnce() {
        #expect(tapCount(signal(tapsAt: [30])) == 1)
    }

    @Test func tapsInAGroupAllCount() {
        #expect(tapCount(signal(tapsAt: [30, 42])) == 2)
        #expect(tapCount(signal(tapsAt: [30, 42, 54])) == 3)
    }

    @Test func aMuchWeakerBounceIsTheSameTap() {
        let strong = signal(tapsAt: [30])
        let bounce = signal(tapsAt: [39], strength: 0.3)
        #expect(tapCount(zip(strong, bounce).map(+), threshold: 0.2) == 1)
    }

    @Test func aFastTripleTapCounts() {
        // Taps 160 ms apart, which is faster than most people tap.
        #expect(tapCount(signal(tapsAt: [30, 38, 46])) == 3)
    }

    @Test func aWeakerSecondTapStillCounts() {
        let strong = signal(tapsAt: [30])
        let weak = signal(tapsAt: [45], strength: 0.5)
        #expect(tapCount(zip(strong, weak).map(+)) == 2)
    }

    @Test func aJoltThatStartsATurnIsNotATap() {
        // Calm at the jolt, but the case keeps turning after it.
        var detector = TapDetector(threshold: 0.3)
        var taps = 0
        let values = signal(tapsAt: [30])
        for (index, value) in values.enumerated() {
            let tap = detector.process(
                acceleration: Vector3(x: value, y: 0, z: 0),
                rotation: Vector3(x: index >= 30 ? 1.5 : 0, y: 0, z: 0),
                at: Double(index) * sampleInterval
            )
            if tap != nil { taps += 1 }
        }
        #expect(taps == 0)
    }

    @Test func accelerationThatBuildsUpIsNotATap() {
        // A smooth push: over 1 g, but with no sharp jolt.
        let push = (0..<120).map { index -> Double in
            let phase = (Double(index) - 30) / 15
            return (0...1).contains(phase) ? 1.2 * sin(phase * .pi) : 0
        }
        #expect(tapCount(push) == 0)
    }

    @Test func falseTapsCannotChainWhileMoving() {
        // One tap while steady, then jolts that never let the shake fade.
        var detector = TapDetector(threshold: 0.3)
        var taps = 0
        let values = signal(tapsAt: Array(stride(from: 30, to: 150, by: 10)), length: 170)
        for (index, value) in values.enumerated() {
            let tap = detector.process(
                acceleration: Vector3(x: value, y: 0, z: 0),
                rotation: .zero,
                at: Double(index) * sampleInterval
            )
            if tap != nil { taps += 1 }
        }
        #expect(taps == 3)
    }

    @Test func smallChangesAreIgnored() {
        #expect(tapCount((0..<60).map { $0.isMultiple(of: 2) ? 0.05 : 0 }) == 0)
    }

    @Test func aJoltWhileRotatingFastIsIgnored() {
        #expect(tapCount(signal(tapsAt: [30]), rotation: 2) == 0)
    }

    @Test func gyroShakeFromATapDoesNotBlockTheNext() {
        var detector = TapDetector(threshold: 0.3)
        var taps = 0
        let values = signal(tapsAt: [30, 42])
        for (index, value) in values.enumerated() {
            // Fast but back and forth, so the case doesn't actually turn.
            let shake = (31...41).contains(index) ? (index.isMultiple(of: 2) ? 2.5 : -2.5) : 0.0
            let tap = detector.process(
                acceleration: Vector3(x: value, y: 0, z: 0),
                rotation: Vector3(x: shake, y: 0, z: 0),
                at: Double(index) * sampleInterval
            )
            if tap != nil { taps += 1 }
        }
        #expect(taps == 2)
    }

    @Test func sustainedShakingCountsAtMostOnce() {
        let shake = (0..<60).map { $0.isMultiple(of: 2) ? 1.0 : 0.0 }
        #expect(tapCount(Array(repeating: 0, count: 20) + shake) <= 1)
    }

    @Test func steadyMovementRaisesTheBar() {
        // Constant movement over half the jolt size, so the jolt doesn't stand out.
        let moving = (0..<80).map { $0.isMultiple(of: 2) ? 0.6 : 0.0 }
        var withJolt = moving
        withJolt[60] = 1.0
        #expect(tapCount(moving) <= 1)
        #expect(tapCount(withJolt) <= 1)
    }
}

/// Replays motion recorded from real AirPods in a case, with the prompts it answered.
@Suite struct RecordedTapTests {
    private struct Replay {
        var gestures: [(time: Double, gesture: CaseGesture)] = []
        var prompts: [(time: Double, gesture: CaseGesture)] = []
        var events: [(time: Double, name: String)] = []
    }

    /// Recorded with a firm tapping style, from the tap test through the gesture test.
    private let firmTaps = CaseCalibration(
        horizontalAxis: Vector3(x: -0.40161, y: 0.49439, z: 0.7709),
        verticalAxis: Vector3(x: 0.13318, y: -0.80129, z: 0.58327),
        gyroBias: Vector3(x: -0.03627, y: 0.00502, z: 0.02783),
        tapThreshold: 0.22364,
        sensorLocation: "left"
    )
    /// Recorded with a lighter tapping style, from calibration through the movement test.
    private let lightTaps = CaseCalibration(
        horizontalAxis: Vector3(x: -0.40438, y: 0.44057, z: 0.80148),
        verticalAxis: Vector3(x: -0.16617, y: 0.82635, z: -0.53808),
        gyroBias: Vector3(x: -0.07101, y: 0.0518, z: 0.10237),
        tapThreshold: 0.10693,
        sensorLocation: "left"
    )

    private func replay(_ file: String, calibration: CaseCalibration) throws -> Replay {
        let url = try #require(Bundle.module.url(forResource: file, withExtension: "csv", subdirectory: "Fixtures"))
        var processor = CaseInputProcessor(calibration: calibration)
        var result = Replay()
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst() {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let time = try #require(Double(fields[0]))
            if fields[1].isEmpty {
                let event = fields[7]
                result.events.append((time, event))
                if let range = event.range(of: "ask:"),
                   let gesture = CaseGesture(rawValue: String(event[range.upperBound...])) {
                    result.prompts.append((time, gesture))
                }
                continue
            }
            let values = fields[1...6].compactMap(Double.init)
            let output = processor.process(MotionReading(
                rotationRate: Vector3(x: values[3], y: values[4], z: values[5]),
                userAcceleration: Vector3(x: values[0], y: values[1], z: values[2]),
                timestamp: time
            ))
            if let gesture = output.gesture {
                result.gestures.append((time, gesture))
            }
        }
        return result
    }

    /// How many prompts were first answered with the right gesture.
    private func correctAnswers(in result: Replay, until end: Double) -> Int {
        var correct = 0
        for (index, prompt) in result.prompts.enumerated() {
            let next = index + 1 < result.prompts.count ? result.prompts[index + 1].time : end
            let answer = result.gestures.first { $0.time >= prompt.time && $0.time < next }
            if answer?.gesture == prompt.gesture { correct += 1 }
        }
        return correct
    }

    private func time(of event: String, in result: Replay) throws -> Double {
        try #require(result.events.first { $0.name == event }).time
    }

    @Test func promptedGesturesAreRecognized() throws {
        let result = try replay("real-taps", calibration: firmTaps)
        #expect(result.prompts.count == CaseCheck.gesturePrompts.count)
        let end = try time(of: "end:gestureTest", in: result)
        // The recording stops soon after the last tap, before its gesture is due.
        // The firmest tapper here is near the limit the setup test itself passes at.
        #expect(correctAnswers(in: result, until: end + 1) >= 7)
    }

    @Test func lighterPromptedGesturesAreRecognized() throws {
        let result = try replay("real-movement", calibration: lightTaps)
        #expect(result.prompts.count == CaseCheck.gesturePrompts.count)
        let end = try time(of: "step:moveTest", in: result)
        #expect(correctAnswers(in: result, until: end) >= 7)
    }

    @Test func singleTapsStaySingle() throws {
        let result = try replay("real-taps", calibration: firmTaps)
        let end = try time(of: "end:tapTest", in: result)
        // The recording starts a second before the tap test, during calibration, so
        // the first gesture here can be the last calibration tap.
        let answers = result.gestures.filter { $0.time >= 1.3 && $0.time < end }
        #expect(answers.count == CaseCheck.tapPrompts)
        #expect(answers.filter { $0.gesture == .single }.count >= 8)
    }

    @Test func movingAndShakingAreNotTaps() throws {
        let result = try replay("real-movement", calibration: lightTaps)
        let start = try time(of: "step:moveTest", in: result)
        // Fifteen seconds of waving and shaking, up to 6 g. One light tap, answering
        // the last gesture prompt, lands in the first second.
        #expect(result.gestures.filter { $0.time >= start + 1 }.isEmpty)
    }

    @Test func calibrationSweepsAreNotTaps() throws {
        let result = try replay("real-movement", calibration: lightTaps)
        // The sweeps and turns come first, and the calibration taps come after them.
        #expect(result.gestures.filter { $0.time < 13 }.isEmpty)
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

    @Test func flipsReverseDirection() {
        var configuration = PointerConfiguration()
        configuration.invertHorizontal = true
        configuration.invertVertical = true
        var pointer = PointerEngine(configuration: configuration)
        let point = sweep(&pointer, horizontal: 30, vertical: 30, seconds: 0.5)
        #expect(point.x < 0.5)
        #expect(point.y > 0.5)
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

    @Test func tremorInsideTheDeadZoneDoesNothing() {
        var pointer = PointerEngine()
        #expect(isAtCenter(sweep(&pointer, horizontal: 1.5, vertical: -1.5, seconds: 2)))
    }

    @Test func staysOnTheDisplay() {
        var pointer = engine()
        let point = sweep(&pointer, horizontal: 300, vertical: -300, seconds: 3)
        #expect(abs(point.x - 1) < 1e-9)
        #expect(abs(point.y - 1) < 1e-9)
    }

    @Test func aLongGapDoesNotJump() {
        var pointer = engine()
        _ = pointer.advance(horizontalRate: 100, verticalRate: 0, at: 0)
        #expect(pointer.advance(horizontalRate: 100, verticalRate: 0, at: 5) == .center)
    }

    @Test func rollBackUndoesTheLastMovement() {
        var pointer = engine()
        _ = sweep(&pointer, seconds: 0.1)
        _ = sweep(&pointer, horizontal: 200, seconds: 0.1, from: 0.12)
        let moved = pointer.position.x
        pointer.rollBack(from: 0.24)
        #expect(pointer.position.x < moved)
    }

    @Test func easingMovesPartWayAndSettles() {
        let start = PointerPoint(x: 0, y: 0)
        let target = PointerPoint(x: 1, y: 1)
        let step = start.eased(toward: target, elapsed: 0.01, timeConstant: 0.035)
        #expect(step.x > 0 && step.x < 1)
        #expect(start.eased(toward: target, elapsed: 1, timeConstant: 0.035).x > 0.999)
    }
}

@Suite struct CaseInputProcessorTests {
    @Test func aTapMakesAGestureAndKeepsThePointerStill() {
        var processor = CaseInputProcessor(calibration: calibration())
        var gestures: [CaseGesture] = []
        var points: [PointerPoint] = []
        for index in 0..<80 {
            let isTap = index == 20
            let output = processor.process(reading(
                rotation: isTap ? Vector3(x: 5, y: 0, z: 5) : .zero,
                acceleration: Vector3(x: isTap ? 1 : 0, y: 0, z: 0),
                at: Double(index) * sampleInterval
            ))
            points.append(output.point)
            if let gesture = output.gesture { gestures.append(gesture) }
        }
        #expect(gestures == [.single])
        #expect(points.allSatisfy(isAtCenter))
    }

    @Test func rotationUsesTheCalibratedAxes() {
        var processor = CaseInputProcessor(calibration: calibration())
        var point = PointerPoint.center
        for index in 0..<50 {
            point = processor.process(reading(
                rotation: Vector3(x: 0, y: 0, z: 20 * degree),
                at: Double(index) * sampleInterval
            )).point
        }
        #expect(point.x > 0.6)
        #expect(abs(point.y - 0.5) < 0.001)
    }

    @Test func gyroBiasIsRemoved() {
        var base = calibration()
        base.gyroBias = Vector3(x: 0, y: 0, z: 20 * degree)
        var processor = CaseInputProcessor(calibration: base)
        var point = PointerPoint.center
        for index in 0..<50 {
            point = processor.process(reading(rotation: base.gyroBias, at: Double(index) * sampleInterval)).point
        }
        #expect(isAtCenter(point))
    }

    @Test func sensitivityChangesWhatCountsAsATap() {
        func gestureCount(sensitivity: Double) -> Int {
            var processor = CaseInputProcessor(calibration: calibration(tapThreshold: 0.6))
            processor.tapSensitivity = sensitivity
            var count = 0
            for index in 0..<80 {
                let output = processor.process(reading(
                    acceleration: Vector3(x: index == 20 ? 0.4 : 0, y: 0, z: 0),
                    at: Double(index) * sampleInterval
                ))
                if output.gesture != nil { count += 1 }
            }
            return count
        }
        #expect(gestureCount(sensitivity: 1) == 0)
        #expect(gestureCount(sensitivity: 2) == 1)
    }
}

@Suite struct ControlModeTests {
    @Test func gesturesMapToActions() {
        #expect(CaseAction(gesture: .single, mode: .presenter) == .nextSlide)
        #expect(CaseAction(gesture: .double, mode: .presenter) == .previousSlide)
        #expect(CaseAction(gesture: .single, mode: .mouse) == .click)
        #expect(CaseAction(gesture: .double, mode: .mouse) == .doubleClick)
        #expect(CaseAction(gesture: .triple, mode: .presenter) == .togglePointer)
        #expect(CaseAction(gesture: .triple, mode: .mouse) == .togglePointer)
        #expect(CaseAction(gesture: .single, mode: .off) == nil)
    }
}

@Suite struct SampleRateTrackerTests {
    @Test func measuresRateAndGaps() {
        var tracker = SampleRateTracker()
        #expect(tracker.snapshot == .empty)
        for time in [0, 0.02, 0.04, 0.54, 0.56] {
            tracker.record(time)
        }
        #expect(abs(tracker.snapshot.longestGapMilliseconds - 500) < 0.01)
        #expect(abs(tracker.snapshot.hertz - 4 / 0.56) < 0.01)
    }

    @Test func forgetsOldSamples() {
        var tracker = SampleRateTracker(windowSeconds: 1)
        tracker.record(0)
        tracker.record(10)
        tracker.record(10.1)
        #expect(tracker.snapshot.longestGapMilliseconds < 101)
    }
}

@Suite struct CaseCheckTests {
    private let wide = 16.0 / 10.0

    /// A check that has reached the tap test, with motion arriving up to the given time.
    private func checkAtTapTest(at time: Double = 10) -> CaseCheck {
        var check = CaseCheck()
        check.processMotion(rotationSpeed: 0, at: time - 5)
        check.confirmEarDetectionOff()
        check.confirmInCase(at: time - 4)
        var clock = time - 3.5
        while check.step == .watchingCase {
            check.processMotion(rotationSpeed: 2, at: clock)
            clock += 0.02
        }
        check.processMotion(rotationSpeed: 0, at: time)
        check.calibrationFinished(at: time)
        return check
    }

    /// From the tap test, answers every gesture prompt correctly. Returns the time it ends.
    private func finishGestures(_ check: inout CaseCheck, from start: Double) -> Double {
        let tapEnd = start + Double(CaseCheck.tapPrompts) * CaseCheck.tapIntervalSeconds
        advance(&check, from: start, to: tapEnd + 0.5)
        #expect(check.step == .gestureTest)

        var clock = tapEnd + 0.5
        advance(&check, from: clock, to: clock + CaseCheck.getReadySeconds + 0.5)
        clock += CaseCheck.getReadySeconds + 1
        for gesture in CaseCheck.gesturePrompts {
            check.registerGesture(gesture, at: clock)
            advance(&check, from: clock, to: clock + CaseCheck.gesturePauseSeconds)
            clock += CaseCheck.gesturePauseSeconds + 0.5
        }
        #expect(check.step == .moveTest)
        return clock
    }

    /// Advances time with motion arriving, so the check doesn't think motion stopped.
    private func advance(_ check: inout CaseCheck, from start: Double, to end: Double) {
        var clock = start
        while clock <= end {
            check.processMotion(rotationSpeed: 0, at: clock)
            check.tick(at: clock)
            clock += 0.5
        }
    }

    @Test func motionMovesPastConnecting() {
        var check = CaseCheck()
        #expect(check.step == .connect)
        check.processMotion(rotationSpeed: 0, at: 1)
        #expect(check.step == .earDetection)
    }

    @Test func movingTheCaseLeadsToCalibration() {
        var check = CaseCheck()
        check.processMotion(rotationSpeed: 0, at: 1)
        check.confirmEarDetectionOff()
        check.confirmInCase(at: 2)
        #expect(check.step == .watchingCase)

        check.processMotion(rotationSpeed: 0, at: 2.1)
        check.processMotion(rotationSpeed: 0, at: 2.2)
        #expect(check.step == .watchingCase)

        var clock = 2.3
        for _ in 0..<40 {
            check.processMotion(rotationSpeed: 2, at: clock)
            clock += 0.02
        }
        #expect(check.step == .calibrate)
    }

    @Test func motionStoppingInTheCaseIsReported() {
        var check = CaseCheck()
        check.processMotion(rotationSpeed: 0, at: 1)
        check.confirmEarDetectionOff()
        check.confirmInCase(at: 50)
        check.tick(at: 52)
        #expect(check.step == .watchingCase)
        check.tick(at: 53.1)
        #expect(check.step == .motionLost)

        check.returnToEarDetection()
        #expect(check.step == .earDetection)
    }

    @Test func motionReturningResumesWatching() {
        var check = CaseCheck()
        check.processMotion(rotationSpeed: 0, at: 1)
        check.confirmEarDetectionOff()
        check.confirmInCase(at: 50)
        check.tick(at: 54)
        check.processMotion(rotationSpeed: 0, at: 55)
        #expect(check.step == .watchingCase)
    }

    @Test func tapsBeforePromptsAreIgnored() {
        var check = checkAtTapTest()
        check.registerTap(at: 11, point: .center, aspectRatio: wide)
        #expect(check.results.tapsHit == 0)
        #expect(check.tapPromptNumber(at: 11) == nil)
        #expect(check.secondsUntilTapsStart(at: 11) == 2)
    }

    @Test func tapsAreScoredPerPrompt() {
        var check = checkAtTapTest()
        let start = 10 + CaseCheck.getReadySeconds
        #expect(check.tapPromptNumber(at: start) == 1)
        #expect(check.tapPromptNumber(at: start + 2.6) == 2)

        check.registerTap(at: start + 1, point: .center, aspectRatio: wide)
        check.registerTap(at: start + 1.5, point: .center, aspectRatio: wide)
        check.registerTap(at: start + 3, point: .center, aspectRatio: wide)
        #expect(check.results.tapsHit == 2)
        #expect(check.results.extraTaps == 1)
    }

    @Test func runsThroughEveryTestToResults() {
        var check = checkAtTapTest()
        let start = 10 + CaseCheck.getReadySeconds
        for prompt in 0..<CaseCheck.tapPrompts {
            check.registerTap(
                at: start + Double(prompt) * CaseCheck.tapIntervalSeconds + 1,
                point: .center,
                aspectRatio: wide
            )
        }
        let gestureEnd = finishGestures(&check, from: start)

        check.registerTap(at: gestureEnd + 1, point: .center, aspectRatio: wide)
        advance(&check, from: gestureEnd, to: gestureEnd + 1 + CaseCheck.moveSeconds)
        #expect(check.step == .pointTest)
        #expect(check.currentTarget == CaseCheck.targets[0])

        // A miss keeps the same target.
        check.registerTap(at: gestureEnd + 17, point: PointerPoint(x: 1, y: 1), aspectRatio: wide)
        #expect(check.targetIndex == 0)

        for target in CaseCheck.targets {
            check.registerTap(at: gestureEnd + 18, point: target, aspectRatio: wide)
        }
        #expect(check.step == .results)
        #expect(check.currentTarget == nil)
        #expect(check.results.tapsHit == 10)
        #expect(check.results.gesturesHit == CaseCheck.gesturePrompts.count)
        #expect(check.results.falseTapsWhileMoving == 1)
        #expect(check.results.targetsHit == 5)
        #expect(check.results.passed)
    }

    @Test func testsCanRunAgainFromResults() {
        var check = checkAtTapTest()
        let start = 10 + CaseCheck.getReadySeconds
        check.registerTap(at: start + 1, point: .center, aspectRatio: wide)
        let gestureEnd = finishGestures(&check, from: start)
        let moveEnd = gestureEnd + CaseCheck.moveSeconds
        advance(&check, from: gestureEnd, to: moveEnd + 1)
        for target in CaseCheck.targets {
            check.registerTap(at: moveEnd + 2, point: target, aspectRatio: wide)
        }
        #expect(check.step == .results)

        check.restartTests(at: moveEnd + 3)
        #expect(check.step == .tapTest)
        #expect(check.results == CaseCheckResults())
        #expect(check.tapPromptNumber(at: moveEnd + 3 + CaseCheck.getReadySeconds) == 1)
    }

    @Test func aMissedTargetTimesOut() {
        var check = checkAtTapTest()
        let start = 10 + CaseCheck.getReadySeconds
        let moveEnd = finishGestures(&check, from: start) + CaseCheck.moveSeconds
        advance(&check, from: moveEnd - CaseCheck.moveSeconds, to: moveEnd + 1)
        #expect(check.step == .pointTest)
        advance(&check, from: moveEnd + 1, to: moveEnd + 2 + CaseCheck.targetTimeoutSeconds)
        #expect(check.targetIndex == 1)
        #expect(check.results.targetsHit == 0)
    }

    @Test func wrongAndMissingGesturesAreScored() {
        var check = checkAtTapTest()
        let start = 10 + CaseCheck.getReadySeconds
        let tapEnd = start + Double(CaseCheck.tapPrompts) * CaseCheck.tapIntervalSeconds
        advance(&check, from: start, to: tapEnd + 0.5)
        var clock = tapEnd + 0.5

        // A gesture during the countdown doesn't count.
        check.registerGesture(.single, at: clock)
        #expect(check.gestureIndex == 0)

        clock += CaseCheck.getReadySeconds + 0.5
        #expect(check.gesturePrompt(at: clock) == .single)
        check.registerGesture(.double, at: clock)
        #expect(check.lastGestureAnswer == .recognized(.double))
        #expect(check.results.gesturesHit == 0)
        #expect(check.gesturePrompt(at: clock) == nil)

        clock += CaseCheck.gesturePauseSeconds
        #expect(check.gesturePrompt(at: clock) == .double)
        advance(&check, from: clock, to: clock + CaseCheck.gestureTimeoutSeconds + 0.5)
        #expect(check.lastGestureAnswer == .nothing)
        #expect(check.gestureIndex == 2)
    }

    @Test func motionStoppingDuringATestIsReported() {
        var check = checkAtTapTest()
        check.tick(at: 14)
        #expect(check.step == .motionLost)
    }

    @Test func passMarks() {
        var results = CaseCheckResults()
        results.tapsHit = 8
        results.extraTaps = 1
        results.falseTapsWhileMoving = 1
        results.targetsHit = 4
        results.gesturesHit = 7
        #expect(results.passed)

        results.tapsHit = 7
        #expect(!results.tapsPassed)
        #expect(!results.passed)
    }

    @Test func aReportIncludesCheckResults() {
        var results = CaseCheckResults()
        results.tapsHit = 9
        let report = SessionReport(
            appVersion: "0.1.0",
            macOSVersion: "27.0",
            motion: .empty,
            sensorLocations: [],
            isCalibrated: true,
            gestureCounts: [:],
            checkResults: results,
            events: []
        ).markdown
        #expect(report.contains("Taps detected: 9 of 10, with 0 extra"))
    }
}

@Suite struct SessionReportTests {
    @Test func includesMeasurementsAndEvents() {
        let report = SessionReport(
            appVersion: "0.1.0",
            macOSVersion: "27.0",
            motion: SampleRateSnapshot(hertz: 50, longestGapMilliseconds: 80),
            sensorLocations: ["left"],
            isCalibrated: true,
            gestureCounts: [.single: 3],
            events: ["12:00:00 Tap"]
        ).markdown
        #expect(report.contains("Motion rate: 50.0 Hz"))
        #expect(report.contains("AirPods sending motion: left"))
        #expect(report.contains("single: 3, double: 0, triple: 0"))
        #expect(report.contains("12:00:00 Tap"))
    }
}
