import Foundation
import SwiftData

enum CharacterStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case woman
    case man

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .woman: return NSLocalizedString("character.woman", comment: "")
        case .man:   return NSLocalizedString("character.man", comment: "")
        }
    }

    /// Asset catalog image names used by WorkoutCharacterView.
    func upImageName(for exercise: ExerciseType) -> String {
        switch (self, exercise) {
        case (.woman, .squat):        return "SquatUp"
        case (.man,   .squat):        return "SquatUpMan"
        case (.woman, .pushUp):       return "PushUpUp"
        case (.man,   .pushUp):       return "PushUpUpMan"
        case (.woman, .jumpingJacks): return "JumpingJackUp"
        case (.man,   .jumpingJacks): return "JumpingJackUpMan"
        case (.woman, .lunge):        return "LungeUp"
        case (.man,   .lunge):        return "LungeUpMan"
        }
    }

    func downImageName(for exercise: ExerciseType) -> String {
        switch (self, exercise) {
        case (.woman, .squat):        return "SquatDown"
        case (.man,   .squat):        return "SquatDownMan"
        case (.woman, .pushUp):       return "PushUpDown"
        case (.man,   .pushUp):       return "PushUpDownMan"
        case (.woman, .jumpingJacks): return "JumpingJackDown"
        case (.man,   .jumpingJacks): return "JumpingJackDownMan"
        case (.woman, .lunge):        return "LungeDown"
        case (.man,   .lunge):        return "LungeDownMan"
        }
    }
}

@Model
final class UserSettings: Sendable {
    @Attribute(.unique) var id: UUID
    var dailyMaxUnlockMinutes: Int
    var isDebugModeEnabled: Bool
    var hasCompletedOnboarding: Bool
    var selectedExerciseTypesRaw: [String]
    var defaultDailyLimitMinutes: Int
    var hapticFeedbackEnabled: Bool
    var characterStyleRaw: String = "woman"
    var updatedAt: Date

    var selectedExerciseTypes: [ExerciseType] {
        selectedExerciseTypesRaw.compactMap { ExerciseType(rawValue: $0) }
    }

    var characterStyle: CharacterStyle {
        get { CharacterStyle(rawValue: characterStyleRaw) ?? .woman }
        set { characterStyleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        dailyMaxUnlockMinutes: Int = 120,
        isDebugModeEnabled: Bool = false,
        hasCompletedOnboarding: Bool = false,
        selectedExerciseTypes: [ExerciseType] = ExerciseType.allCases.filter { $0.stability == .stable },
        defaultDailyLimitMinutes: Int = 30,
        hapticFeedbackEnabled: Bool = true,
        characterStyle: CharacterStyle = .woman
    ) {
        self.id = id
        self.dailyMaxUnlockMinutes = dailyMaxUnlockMinutes
        self.isDebugModeEnabled = isDebugModeEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedExerciseTypesRaw = selectedExerciseTypes.map { $0.rawValue }
        self.defaultDailyLimitMinutes = defaultDailyLimitMinutes
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.characterStyleRaw = characterStyle.rawValue
        self.updatedAt = Date()
    }
}
