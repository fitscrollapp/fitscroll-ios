import Foundation
import SwiftUI

/// Leaderboard data source. Primary source is the FitScroll backend
/// (`FitScrollAPI.leaderboard`); when the backend is unreachable (or the user
/// hasn't picked a username yet) it falls back to the original local ranking:
/// ~25 deterministic demo players + the real user spliced in.
@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var category: LeaderboardCategory = .pushUps
    @Published var period: LeaderboardPeriod = .weekly

    /// Entries fetched from the backend for the CURRENT category+period.
    /// nil → backend unavailable → local fallback is shown.
    @Published var remoteEntries: [RankedEntry]?
    @Published var isRefreshing = false

    /// One username re-sync attempt per app launch — covers the case where
    /// the name was picked while offline and never reached the backend.
    private var didAttemptUsernameSync = false

    let bots: [LeaderboardPlayer] = LeaderboardViewModel.seedBots()

    // MARK: - Backend refresh

    /// Pull the board for the current category+period from the backend.
    func refresh() async {
        guard let stored = Self.storedUsername else {
            remoteEntries = nil
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        if !didAttemptUsernameSync {
            didAttemptUsernameSync = true
            if let user = try? await FitScrollAPI.shared.identify(),
               user.username == nil {
                try? await FitScrollAPI.shared.setUsername(stored)
            }
        }

        do {
            let resp = try await FitScrollAPI.shared.leaderboard(
                exercise: category.exercise,
                period: period
            )
            remoteEntries = resp.entries.map { e in
                RankedEntry(
                    rank: e.rank,
                    player: LeaderboardPlayer(
                        id: "u_\(e.username)",
                        name: e.username,
                        isCurrentUser: e.isMe,
                        weekly: .zero, allTime: .zero
                    ),
                    score: e.score
                )
            }
        } catch {
            Logger.log("leaderboard fetch failed: \(error.localizedDescription)", level: .warning)
            remoteEntries = nil
        }
    }

    // MARK: - User stats from real sessions

    func userStats(from sessions: [WorkoutSession]) -> UserStats {
        let weeklyStart = LeaderboardViewModel.startOfWeek(Date())

        var minutes = 0.0
        var pushUps = 0, squats = 0, jj = 0, lunges = 0
        for s in sessions {
            minutes += s.earnedMinutes
            switch s.exerciseType {
            case .pushUp: pushUps += s.repCount
            case .squat: squats += s.repCount
            case .jumpingJacks: jj += s.repCount
            case .lunge: lunges += s.repCount
            case .none: break
            }
        }

        // Best weekly rank across categories requires the ranking itself, so we
        // compute it after building weekly entries below.
        var stats = UserStats(
            totalMinutes: Int(minutes.rounded()),
            pushUps: pushUps, squats: squats, jumpingJacks: jj, lunges: lunges,
            streak: JourneyService.currentStreak(sessions: sessions),
            bestWeeklyRank: 999
        )

        var best = 999
        for cat in LeaderboardCategory.allCases {
            let entries = rankedEntries(sessions: sessions, category: cat, period: .weekly)
            if let me = entries.first(where: { $0.player.isCurrentUser }) {
                best = min(best, me.rank)
            }
        }
        stats.bestWeeklyRank = best
        _ = weeklyStart
        return stats
    }

    private func userPlayer(from sessions: [WorkoutSession]) -> LeaderboardPlayer {
        let weeklyStart = LeaderboardViewModel.startOfWeek(Date())

        var w = CategoryScores.zero
        var a = CategoryScores.zero

        for s in sessions {
            let inWeek = s.startedAt >= weeklyStart
            switch s.exerciseType {
            case .pushUp:
                a.pushUps += s.repCount; if inWeek { w.pushUps += s.repCount }
            case .squat:
                a.squats += s.repCount; if inWeek { w.squats += s.repCount }
            case .jumpingJacks:
                a.jumpingJacks += s.repCount; if inWeek { w.jumpingJacks += s.repCount }
            case .lunge:
                a.lunges += s.repCount; if inWeek { w.lunges += s.repCount }
            case .none:
                break
            }
        }

        return LeaderboardPlayer(
            id: "current_user", name: Self.storedUsername ?? "You", isCurrentUser: true,
            weekly: w, allTime: a
        )
    }

    /// Username the user picked in the leaderboard gate popup.
    static var storedUsername: String? {
        let v = UserDefaults.standard.string(forKey: "fitscroll.username")
        return (v?.isEmpty ?? true) ? nil : v
    }

    // MARK: - Ranking

    func rankedEntries(sessions: [WorkoutSession]) -> [RankedEntry] {
        rankedEntries(sessions: sessions, category: category, period: period)
    }

    func rankedEntries(
        sessions: [WorkoutSession],
        category: LeaderboardCategory,
        period: LeaderboardPeriod
    ) -> [RankedEntry] {
        let user = userPlayer(from: sessions)
        let players = bots + [user]

        // Sort by score desc; break ties in the user's favour so a new player
        // with a small/zero score never lands dead last among equal scores.
        let sorted = players.sorted { lhs, rhs in
            let l = lhs.scores(for: period).value(for: category)
            let r = rhs.scores(for: period).value(for: category)
            if l != r { return l > r }
            if lhs.isCurrentUser != rhs.isCurrentUser { return lhs.isCurrentUser }
            return lhs.name < rhs.name
        }

        return sorted.enumerated().map { idx, player in
            RankedEntry(
                rank: idx + 1,
                player: player,
                score: player.scores(for: period).value(for: category)
            )
        }
    }

    // MARK: - Badges

    func badges(sessions: [WorkoutSession]) -> [(badge: LeaderboardBadge, earned: Bool)] {
        let stats = userStats(from: sessions)
        return LeaderboardBadge.all.map { ($0, $0.requirement.isSatisfied(by: stats)) }
    }

    // MARK: - Weekly reset countdown

    /// e.g. "Resets in 3d 7h" — time until next Monday 00:00 local.
    func resetCountdown(now: Date = Date()) -> String {
        let start = LeaderboardViewModel.startOfWeek(now)
        guard let next = Calendar.current.date(byAdding: .day, value: 7, to: start) else {
            return "Resets soon"
        }
        let secs = max(0, Int(next.timeIntervalSince(now)))
        let days = secs / 86_400
        let hours = (secs % 86_400) / 3_600
        return "Resets in \(days)d \(hours)h"
    }

    static func startOfWeek(_ now: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return cal.date(from: comps) ?? now
    }

    // MARK: - Seed data (deterministic, no randomness)

    private static func seedBots() -> [LeaderboardPlayer] {
        let names = [
            "Sofia", "Liam", "Mateo", "Yuki", "Aisha",
            "Noah", "Elena", "Omar", "Chen", "Isabella",
            "Arjun", "Fatima", "Lucas", "Nina", "Diego",
            "Priya", "Hugo", "Mei", "Youssef", "Clara",
            "Ravi", "Zoe", "Andrei", "Leila", "Marcus",
        ]
        // All-time "power" — spread includes strong and weak players.
        let allPower = [
            92, 15, 78, 6, 63, 40, 88, 22, 3, 55,
            71, 12, 48, 34, 97, 8, 60, 27, 84, 19,
            45, 2, 67, 30, 52,
        ]
        // Weekly "power" — several zeros so a new user isn't always last.
        let weekPower = [
            40, 0, 33, 0, 28, 12, 44, 5, 0, 22,
            30, 0, 18, 9, 48, 0, 25, 6, 38, 0,
            15, 0, 27, 8, 20,
        ]

        return names.enumerated().map { i, name in
            let p = allPower[i]
            let wp = weekPower[i]
            let allTime = CategoryScores(
                pushUps: p * 14,
                squats: p * 12,
                jumpingJacks: p * 18,
                lunges: p * 8
            )
            let weekly = CategoryScores(
                pushUps: wp * 7,
                squats: wp * 6,
                jumpingJacks: wp * 9,
                lunges: wp * 4
            )
            return LeaderboardPlayer(
                id: "bot_\(i)", name: name, isCurrentUser: false,
                weekly: weekly, allTime: allTime
            )
        }
    }
}
