import Foundation

struct WorkoutRepEvent: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let exerciseType: ExerciseType
    let repNumber: Int
    let confidence: Double
    let wasAccepted: Bool
    let rejectionReason: RepRejectionReason?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        exerciseType: ExerciseType,
        repNumber: Int,
        confidence: Double,
        wasAccepted: Bool = true,
        rejectionReason: RepRejectionReason? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.exerciseType = exerciseType
        self.repNumber = repNumber
        self.confidence = confidence
        self.wasAccepted = wasAccepted
        self.rejectionReason = rejectionReason
    }
}

enum RepRejectionReason: String, Sendable {
    case lowConfidence
    case tooFast
    case incompleteMotion
    case poseNotDetected
}
