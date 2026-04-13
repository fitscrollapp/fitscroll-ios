import Foundation
import SwiftData

@Model
final class ExerciseRewardRule: Sendable {
    var exerciseTypeRaw: String
    var minutesPerRep: Double
    var isEnabled: Bool
    var updatedAt: Date

    var exerciseType: ExerciseType? {
        ExerciseType(rawValue: exerciseTypeRaw)
    }

    init(exerciseType: ExerciseType, minutesPerRep: Double? = nil, isEnabled: Bool = true) {
        self.exerciseTypeRaw = exerciseType.rawValue
        self.minutesPerRep = minutesPerRep ?? exerciseType.defaultMinutesPerRep
        self.isEnabled = isEnabled
        self.updatedAt = Date()
    }
}
