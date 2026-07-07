import SwiftUI

/// What a badge requires to be earned. Evaluated against `UserStats`.
enum BadgeRequirement {
    case firstWorkout
    case totalReps(Int)
    case pushUps(Int)
    case squats(Int)
    case jumpingJacks(Int)
    case minutes(Int)
    case streak(Int)
    case weeklyRankAtMost(Int)
    /// Aspirational — never auto-earned in this local build.
    case never

    func isSatisfied(by s: UserStats) -> Bool {
        switch self {
        case .firstWorkout: return s.totalReps > 0 || s.totalMinutes > 0
        case .totalReps(let n): return s.totalReps >= n
        case .pushUps(let n): return s.pushUps >= n
        case .squats(let n): return s.squats >= n
        case .jumpingJacks(let n): return s.jumpingJacks >= n
        case .minutes(let n): return s.totalMinutes >= n
        case .streak(let n): return s.streak >= n
        case .weeklyRankAtMost(let n): return s.bestWeeklyRank <= n
        case .never: return false
        }
    }
}

/// A gamified achievement mapped to one of the badge assets.
struct LeaderboardBadge: Identifiable {
    let id: String
    let title: String
    let howToEarn: String
    let asset: String       // asset-catalog template image name
    let colorHex: String    // earned gradient tint
    let requirement: BadgeRequirement

    /// The full shelf. NOTE: titles/descriptions are English literals
    /// (un-localized first pass for the leaderboard feature).
    static let all: [LeaderboardBadge] = [
        LeaderboardBadge(
            id: "first_steps", title: "First Steps",
            howToEarn: "Finish your very first workout.",
            asset: "BadgeMuscle", colorHex: "22F4A8", requirement: .firstWorkout),
        LeaderboardBadge(
            id: "century", title: "Century Club",
            howToEarn: "Reach 100 total reps.",
            asset: "BadgeLightning", colorHex: "3B82F6", requirement: .totalReps(100)),
        LeaderboardBadge(
            id: "king_of_reps", title: "King of Reps",
            howToEarn: "Reach 1,000 total reps.",
            asset: "BadgeFist", colorHex: "FFB020", requirement: .totalReps(1000)),
        LeaderboardBadge(
            id: "push_master", title: "Push Master",
            howToEarn: "Complete 100 push-ups.",
            asset: "BadgeMedal", colorHex: "FF5A5F", requirement: .pushUps(100)),
        LeaderboardBadge(
            id: "squat_squad", title: "Squat Squad",
            howToEarn: "Complete 100 squats.",
            asset: "BadgeMuscle", colorHex: "8B5CF6", requirement: .squats(100)),
        LeaderboardBadge(
            id: "streak_hero", title: "Streak Hero",
            howToEarn: "Keep a 7-day workout streak.",
            asset: "BadgeLaurels", colorHex: "22F4A8", requirement: .streak(7)),
        LeaderboardBadge(
            id: "time_bandit", title: "Time Bandit",
            howToEarn: "Earn 60 minutes of screen time.",
            asset: "BadgeTrophy", colorHex: "FFD65C", requirement: .minutes(60)),
        LeaderboardBadge(
            id: "podium", title: "Podium Finish",
            howToEarn: "Reach the top 3 this week.",
            asset: "BadgePodium", colorHex: "CD7F32", requirement: .weeklyRankAtMost(3)),
        LeaderboardBadge(
            id: "champion", title: "Champion",
            howToEarn: "Claim the #1 spot this week.",
            asset: "BadgeCrown", colorHex: "FFD65C", requirement: .weeklyRankAtMost(1)),
        LeaderboardBadge(
            id: "legend", title: "Legend",
            howToEarn: "Reach 5,000 total reps. The ultimate flex.",
            asset: "BadgeFist", colorHex: "F5A623", requirement: .totalReps(5000)),
    ]
}
