import XCTest
@testable import FitScroll

final class RepDetectionEngineTests: XCTestCase {

    // MARK: - Squat Tests

    func testSquatRepCounting() {
        let engine = RepDetectionEngine(exerciseType: .squat)
        let thresholds = ExerciseThresholds.squat

        // Start in idle - send high angle (standing)
        let standingFrame = makeSquatFrame(kneeAngle: thresholds.upAngle + 5, confidence: 0.8)
        _ = engine.processFrame(standingFrame)

        // Go down
        let downFrame = makeSquatFrame(kneeAngle: thresholds.downAngle - 5, confidence: 0.8)
        _ = engine.processFrame(downFrame)

        // Wait for minimum rep duration
        let laterFrame = makeSquatFrame(
            kneeAngle: thresholds.upAngle + 5,
            confidence: 0.8,
            timestamp: Date().addingTimeInterval(thresholds.minimumRepDuration + 0.1)
        )
        let event = engine.processFrame(laterFrame)

        XCTAssertEqual(engine.repCount, 1)
        XCTAssertNotNil(event)
        XCTAssertTrue(event?.wasAccepted ?? false)
    }

    func testLowConfidenceFrameIsIgnored() {
        let engine = RepDetectionEngine(exerciseType: .squat)
        let frame = makeSquatFrame(kneeAngle: 90, confidence: 0.1)
        let event = engine.processFrame(frame)

        XCTAssertNil(event)
        XCTAssertEqual(engine.repCount, 0)
    }

    func testResetClearsState() {
        let engine = RepDetectionEngine(exerciseType: .squat)

        // Do a rep cycle
        let frame = makeSquatFrame(kneeAngle: 80, confidence: 0.8)
        _ = engine.processFrame(frame)

        engine.reset()

        XCTAssertEqual(engine.repCount, 0)
        XCTAssertEqual(engine.currentPhase, .idle)
    }

    // MARK: - Push-up Tests

    func testPushUpRepDetection() {
        let engine = RepDetectionEngine(exerciseType: .pushUp)
        let thresholds = ExerciseThresholds.pushUp

        // Arm extended (high angle)
        let extendedFrame = makePushUpFrame(elbowAngle: thresholds.upAngle + 5, confidence: 0.8)
        _ = engine.processFrame(extendedFrame)

        // Arm bent (low angle)
        let bentFrame = makePushUpFrame(elbowAngle: thresholds.downAngle - 5, confidence: 0.8)
        _ = engine.processFrame(bentFrame)

        // Back up after minimum duration
        let backUpFrame = makePushUpFrame(
            elbowAngle: thresholds.upAngle + 5,
            confidence: 0.8,
            timestamp: Date().addingTimeInterval(thresholds.minimumRepDuration + 0.1)
        )
        let event = engine.processFrame(backUpFrame)

        XCTAssertEqual(engine.repCount, 1)
        XCTAssertNotNil(event)
    }

    // MARK: - Exercise Type Thresholds

    func testAllExerciseTypesHaveThresholds() {
        for exerciseType in ExerciseType.allCases {
            let thresholds = ExerciseThresholds.thresholds(for: exerciseType)
            XCTAssertGreaterThan(thresholds.minimumConfidence, 0)
            XCTAssertGreaterThan(thresholds.debounceInterval, 0)
            XCTAssertGreaterThan(thresholds.minimumRepDuration, 0)
        }
    }

    // MARK: - Helpers

    private func makeSquatFrame(kneeAngle: Double, confidence: Float, timestamp: Date = Date()) -> PoseFrame {
        // Create joints that produce the desired knee angle
        let radians = kneeAngle * .pi / 180.0
        let hipPoint = PoseFrame.JointPosition(x: 0.5, y: 0.6, confidence: confidence)
        let kneePoint = PoseFrame.JointPosition(x: 0.5, y: 0.4, confidence: confidence)

        // Calculate ankle position to produce desired angle at knee
        let ankleX = 0.5 + 0.2 * sin(radians)
        let ankleY = 0.4 - 0.2 * cos(radians)
        let anklePoint = PoseFrame.JointPosition(x: ankleX, y: ankleY, confidence: confidence)

        return PoseFrame(
            timestamp: timestamp,
            joints: [
                .leftHip: hipPoint, .rightHip: hipPoint,
                .leftKnee: kneePoint, .rightKnee: kneePoint,
                .leftAnkle: anklePoint, .rightAnkle: anklePoint,
                .leftShoulder: PoseFrame.JointPosition(x: 0.5, y: 0.8, confidence: confidence),
                .rightShoulder: PoseFrame.JointPosition(x: 0.5, y: 0.8, confidence: confidence),
                .nose: PoseFrame.JointPosition(x: 0.5, y: 0.9, confidence: confidence),
            ],
            confidence: confidence,
            imageSize: CGSize(width: 720, height: 1280)
        )
    }

    private func makePushUpFrame(elbowAngle: Double, confidence: Float, timestamp: Date = Date()) -> PoseFrame {
        let radians = elbowAngle * .pi / 180.0
        let shoulderPoint = PoseFrame.JointPosition(x: 0.5, y: 0.7, confidence: confidence)
        let elbowPoint = PoseFrame.JointPosition(x: 0.5, y: 0.5, confidence: confidence)

        let wristX = 0.5 + 0.15 * sin(radians)
        let wristY = 0.5 - 0.15 * cos(radians)
        let wristPoint = PoseFrame.JointPosition(x: wristX, y: wristY, confidence: confidence)

        return PoseFrame(
            timestamp: timestamp,
            joints: [
                .leftShoulder: shoulderPoint, .rightShoulder: shoulderPoint,
                .leftElbow: elbowPoint, .rightElbow: elbowPoint,
                .leftWrist: wristPoint, .rightWrist: wristPoint,
                .leftHip: PoseFrame.JointPosition(x: 0.5, y: 0.4, confidence: confidence),
                .rightHip: PoseFrame.JointPosition(x: 0.5, y: 0.4, confidence: confidence),
                .nose: PoseFrame.JointPosition(x: 0.5, y: 0.9, confidence: confidence),
            ],
            confidence: confidence,
            imageSize: CGSize(width: 720, height: 1280)
        )
    }
}
