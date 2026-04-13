import Foundation

@MainActor
final class ExerciseRepCounter: ObservableObject {
    @Published private(set) var repCount: Int = 0
    @Published private(set) var currentPhase: MotionPhase = .idle
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var currentConfidence: Float = 0
    @Published private(set) var currentFrame: PoseFrame?
    @Published private(set) var events: [WorkoutRepEvent] = []
    @Published private(set) var lastRejectionReason: String?

    private let engine: RepDetectionEngine
    let exerciseType: ExerciseType

    init(exerciseType: ExerciseType) {
        self.exerciseType = exerciseType
        self.engine = RepDetectionEngine(exerciseType: exerciseType)

        engine.onDebugUpdate = { [weak self] info in
            Task { @MainActor in
                self?.currentAngle = info.angle
                self?.currentPhase = info.phase
                self?.currentConfidence = info.confidence
                self?.repCount = info.repCount
                if info.wasRejected {
                    self?.lastRejectionReason = info.rejectionReason
                }
            }
        }
    }

    func processFrame(_ frame: PoseFrame) {
        currentFrame = frame
        let event = engine.processFrame(frame)
        if let event {
            events.append(event)
            repCount = engine.repCount
        }
    }

    func reset() {
        engine.reset()
        repCount = 0
        currentPhase = .idle
        currentAngle = 0
        currentConfidence = 0
        currentFrame = nil
        events = []
        lastRejectionReason = nil
    }

    var acceptedReps: Int {
        events.filter { $0.wasAccepted }.count
    }

    var averageConfidence: Double {
        let accepted = events.filter { $0.wasAccepted }
        guard !accepted.isEmpty else { return 0 }
        return accepted.map(\.confidence).reduce(0, +) / Double(accepted.count)
    }
}
