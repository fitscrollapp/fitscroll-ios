import Foundation

enum ExerciseStability: String, Codable, Sendable {
    case stable
    case experimental
}

enum ExerciseType: String, Codable, CaseIterable, Identifiable, Sendable {
    case squat
    case pushUp
    case jumpingJacks
    case lunge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat: return NSLocalizedString("exercise.squat.name", comment: "")
        case .pushUp: return NSLocalizedString("exercise.push_up.name", comment: "")
        case .jumpingJacks: return NSLocalizedString("exercise.jumping_jacks.name", comment: "")
        case .lunge: return NSLocalizedString("exercise.lunge.name", comment: "")
        }
    }

    var stability: ExerciseStability {
        .stable
    }

    var defaultMinutesPerRep: Double {
        switch self {
        case .squat: return 1.0
        case .pushUp: return 1.0
        case .jumpingJacks: return 1.0
        case .lunge: return 1.0
        }
    }

    var iconName: String {
        switch self {
        case .squat: return "figure.strengthtraining.functional"
        case .pushUp: return "figure.strengthtraining.traditional"
        case .jumpingJacks: return "figure.mixed.cardio"
        case .lunge: return "figure.strengthtraining.functional"
        }
    }

    var description: String {
        switch self {
        case .squat: return NSLocalizedString("exercise.squat.description", comment: "")
        case .pushUp: return NSLocalizedString("exercise.push_up.description", comment: "")
        case .jumpingJacks: return NSLocalizedString("exercise.jumping_jacks.description", comment: "")
        case .lunge: return NSLocalizedString("exercise.lunge.description", comment: "")
        }
    }
}
