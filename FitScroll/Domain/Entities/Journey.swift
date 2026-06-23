import Foundation

/// Challenge semantics for a single Journey level. Stored as a small
/// JSON blob inside `JourneyLevel.challengeJSON` so we can evolve the
/// structure without running SwiftData migrations.
enum JourneyChallenge: Codable, Sendable, Equatable {
    /// Do `count` reps of a single exercise in one workout session.
    case reps(exercise: ExerciseType, count: Int)
    /// Complete the list of sub-challenges inside the same session.
    case mixed(steps: [MixedStep])
    /// Work out for at least `minutes` minutes within one session.
    case session(minutes: Double)
    /// Earn at least `minutes` minutes of screen time on a single day.
    case earn(minutes: Int)
    /// Finish at least one workout on `days` consecutive days.
    case streak(days: Int)

    struct MixedStep: Codable, Sendable, Equatable {
        let exercise: ExerciseType
        let count: Int
    }

    var summary: String {
        switch self {
        case .reps(let exercise, let count):
            return "\(count) \(exercise.displayName)"
        case .mixed(let steps):
            return steps.map { "\($0.count) \($0.exercise.displayName)" }
                .joined(separator: " + ")
        case .session(let minutes):
            let n = minutes == minutes.rounded()
                ? String(Int(minutes))
                : String(format: "%.1f", minutes)
            return "\(n) min workout"
        case .earn(let minutes):
            return "Earn \(minutes) min of screen time today"
        case .streak(let days):
            return "\(days) days in a row"
        }
    }
}

/// Visual / thematic grouping of levels.
struct JourneySection: Identifiable, Sendable, Equatable {
    let id: String
    let index: Int
    let title: String
    let tagline: String
    let colorHex: String
    let unlocksExercise: ExerciseType?
}

/// Single bubble on the path. Static content, seeded at app launch.
struct JourneyLevel: Identifiable, Sendable, Equatable {
    let id: String
    let sectionId: String
    let index: Int
    let title: String
    let challenge: JourneyChallenge
    let rewardXP: Int
    let rewardBonusMinutes: Int
    /// If non-nil, this level grants the referenced badge on completion.
    let badgeId: String?
    /// Boss levels get a special appearance at the end of a section.
    let isBoss: Bool
}

/// Earnable badge. Separate from level rewards so a user can earn the
/// same badge from multiple paths (e.g. "First rep" whether they first
/// tried a push-up, squat, or lunge).
struct Badge: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let description: String
    let iconSystemName: String
    let colorHex: String
}
