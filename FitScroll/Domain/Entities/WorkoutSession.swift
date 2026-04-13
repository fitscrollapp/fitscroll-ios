import Foundation
import SwiftData

@Model
final class WorkoutSession: Sendable {
    @Attribute(.unique) var id: UUID
    var exerciseTypeRaw: String
    var repCount: Int
    var earnedMinutes: Double
    var averageConfidence: Double
    var startedAt: Date
    var finishedAt: Date?
    var statusRaw: String

    var exerciseType: ExerciseType? {
        ExerciseType(rawValue: exerciseTypeRaw)
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        exerciseType: ExerciseType,
        repCount: Int = 0,
        earnedMinutes: Double = 0,
        averageConfidence: Double = 0,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        status: SessionStatus = .inProgress
    ) {
        self.id = id
        self.exerciseTypeRaw = exerciseType.rawValue
        self.repCount = repCount
        self.earnedMinutes = earnedMinutes
        self.averageConfidence = averageConfidence
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.statusRaw = status.rawValue
    }
}

enum SessionStatus: String, Codable, Sendable {
    case inProgress
    case completed
    case cancelled
}
