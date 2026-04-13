import Foundation
import AVFoundation

protocol PoseProvider: Sendable {
    func startProviding() async
    func stopProviding() async
    var onPoseFrame: (@Sendable (PoseFrame) -> Void)? { get set }
}

final class MockPoseProvider: PoseProvider, @unchecked Sendable {
    var onPoseFrame: (@Sendable (PoseFrame) -> Void)?
    private var isRunning = false
    private var timer: Task<Void, Never>?
    let exerciseType: ExerciseType
    let repIntervalSeconds: Double

    init(exerciseType: ExerciseType, repIntervalSeconds: Double = 2.0) {
        self.exerciseType = exerciseType
        self.repIntervalSeconds = repIntervalSeconds
    }

    func startProviding() async {
        isRunning = true
        timer = Task {
            var frameIndex = 0
            while isRunning && !Task.isCancelled {
                let frame = generateMockFrame(index: frameIndex)
                onPoseFrame?(frame)
                frameIndex += 1
                try? await Task.sleep(nanoseconds: 33_333_333) // ~30fps
            }
        }
    }

    func stopProviding() async {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    private func generateMockFrame(index: Int) -> PoseFrame {
        let framesPerRep = Int(repIntervalSeconds * 30)
        let cyclePosition = Double(index % framesPerRep) / Double(framesPerRep)
        let angle = simulateAngle(cyclePosition: cyclePosition)
        return createMockFrame(primaryAngle: angle)
    }

    private func simulateAngle(cyclePosition: Double) -> Double {
        let thresholds = ExerciseThresholds.thresholds(for: exerciseType)
        let range = thresholds.upAngle - thresholds.downAngle
        let midAngle = thresholds.downAngle + range / 2
        return midAngle + (range / 2) * cos(cyclePosition * 2 * .pi)
    }

    private func createMockFrame(primaryAngle: Double) -> PoseFrame {
        let radians = primaryAngle * .pi / 180.0
        var joints: [PoseFrame.JointName: PoseFrame.JointPosition] = [:]

        // Create realistic joint positions based on angle
        joints[.leftShoulder] = .init(x: 0.4, y: 0.7, confidence: 0.9)
        joints[.rightShoulder] = .init(x: 0.6, y: 0.7, confidence: 0.9)
        joints[.leftHip] = .init(x: 0.4, y: 0.5, confidence: 0.9)
        joints[.rightHip] = .init(x: 0.6, y: 0.5, confidence: 0.9)

        let elbowY = 0.7 - 0.15 * cos(radians)
        let elbowX = 0.3 - 0.05 * sin(radians)
        joints[.leftElbow] = .init(x: elbowX, y: elbowY, confidence: 0.85)
        joints[.rightElbow] = .init(x: 1.0 - elbowX, y: elbowY, confidence: 0.85)

        let wristY = elbowY - 0.15 * cos(radians / 2)
        joints[.leftWrist] = .init(x: 0.25, y: wristY, confidence: 0.8)
        joints[.rightWrist] = .init(x: 0.75, y: wristY, confidence: 0.8)

        let kneeAngle = primaryAngle * .pi / 180.0
        let kneeY = 0.35 - 0.1 * cos(kneeAngle)
        joints[.leftKnee] = .init(x: 0.4, y: kneeY, confidence: 0.85)
        joints[.rightKnee] = .init(x: 0.6, y: kneeY, confidence: 0.85)

        joints[.leftAnkle] = .init(x: 0.4, y: 0.15, confidence: 0.8)
        joints[.rightAnkle] = .init(x: 0.6, y: 0.15, confidence: 0.8)
        joints[.nose] = .init(x: 0.5, y: 0.85, confidence: 0.9)

        return PoseFrame(
            timestamp: Date(),
            joints: joints,
            confidence: 0.85,
            imageSize: CGSize(width: 720, height: 1280)
        )
    }
}
