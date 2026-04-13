import Foundation

enum ExerciseStability: String, Codable, Sendable {
    case stable
    case experimental
}

enum ExerciseType: String, Codable, CaseIterable, Identifiable, Sendable {
    case squat
    case pushUp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squat: return NSLocalizedString("exercise.squat.name", comment: "")
        case .pushUp: return NSLocalizedString("exercise.push_up.name", comment: "")
        }
    }

    var stability: ExerciseStability {
        .stable
    }

    var defaultMinutesPerRep: Double {
        switch self {
        case .squat: return 1.0
        case .pushUp: return 1.0
        }
    }

    var iconName: String {
        switch self {
        case .squat: return "figure.strengthtraining.functional"
        case .pushUp: return "figure.strengthtraining.traditional"
        }
    }

    var description: String {
        switch self {
        case .squat: return NSLocalizedString("exercise.squat.description", comment: "")
        case .pushUp: return NSLocalizedString("exercise.push_up.description", comment: "")
        }
    }
}
