import SwiftUI

// MARK: - Category & Period

/// Players are ranked per workout category (one leaderboard per exercise).
/// NOTE: user-facing titles here are English literals (a first-pass,
/// un-localized as agreed for the new leaderboard feature).
enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case pushUps
    case squats
    case jumpingJacks
    case lunges

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .pushUps: return "💪"
        case .squats: return "🦵"
        case .jumpingJacks: return "🤸"
        case .lunges: return "🚶"
        }
    }

    var shortTitle: String {
        switch self {
        case .pushUps: return "Push-ups"
        case .squats: return "Squats"
        case .jumpingJacks: return "Jumps"
        case .lunges: return "Lunges"
        }
    }

    /// Unit suffix shown next to a score.
    var unit: String { "reps" }

    /// The workout type this board ranks — rawValue doubles as the API's
    /// exercise identifier.
    var exercise: ExerciseType {
        switch self {
        case .pushUps: return .pushUp
        case .squats: return .squat
        case .jumpingJacks: return .jumpingJacks
        case .lunges: return .lunge
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case weekly
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .allTime: return "All-time"
        }
    }
}

// MARK: - Scores

/// A player's score in every category for a single period.
struct CategoryScores {
    var pushUps: Int
    var squats: Int
    var jumpingJacks: Int
    var lunges: Int

    func value(for category: LeaderboardCategory) -> Int {
        switch category {
        case .pushUps: return pushUps
        case .squats: return squats
        case .jumpingJacks: return jumpingJacks
        case .lunges: return lunges
        }
    }

    static let zero = CategoryScores(pushUps: 0, squats: 0, jumpingJacks: 0, lunges: 0)
}

// MARK: - Player

struct LeaderboardPlayer: Identifiable {
    let id: String
    let name: String
    let isCurrentUser: Bool
    let weekly: CategoryScores
    let allTime: CategoryScores

    func scores(for period: LeaderboardPeriod) -> CategoryScores {
        period == .weekly ? weekly : allTime
    }

    /// Deterministic 1–2 letter avatar initials.
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(name.count >= 2 ? 1 : 1)).uppercased()
    }

    /// Deterministic avatar colour derived from the name (djb2 hash → hue).
    var avatarColor: Color {
        var hash = 5381
        for scalar in name.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.62, brightness: 0.92)
    }
}

/// A player with a computed rank & score for the currently selected
/// category + period.
struct RankedEntry: Identifiable {
    let rank: Int
    let player: LeaderboardPlayer
    let score: Int

    var id: String { player.id }
}

// MARK: - User stats (derived from real WorkoutSession data)

struct UserStats {
    var totalMinutes: Int
    var pushUps: Int
    var squats: Int
    var jumpingJacks: Int
    var lunges: Int
    var streak: Int
    /// Best (lowest) weekly rank the user currently holds across all four
    /// categories. 999 if unranked.
    var bestWeeklyRank: Int

    var totalReps: Int { pushUps + squats + jumpingJacks + lunges }
}
