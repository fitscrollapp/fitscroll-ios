import Foundation
import SwiftData

/// Pure read/compute helpers on top of a `UserJourneyProgress` record
/// and the static `JourneyContent` catalog. Higher-level orchestration
/// (unlock next level, award badges) also lives here so views stay
/// purely presentational.
@MainActor
enum JourneyService {

    /// Current level the user should attempt next — the first level in
    /// content order that isn't yet in `completedLevelIDs`. Returns nil
    /// when the whole Journey is finished.
    static func currentLevel(progress: UserJourneyProgress) -> JourneyLevel? {
        let done = Set(progress.completedLevelIDs)
        for level in JourneyContent.allLevelsInOrder {
            if !done.contains(level.id) { return level }
        }
        return nil
    }

    /// True if the user is allowed to start this level. A level is
    /// unlocked once every earlier level in the linear order is done.
    static func isUnlocked(_ level: JourneyLevel, progress: UserJourneyProgress) -> Bool {
        let order = JourneyContent.allLevelsInOrder
        guard let targetIndex = order.firstIndex(where: { $0.id == level.id }) else {
            return false
        }
        let done = Set(progress.completedLevelIDs)
        for i in 0..<targetIndex {
            if !done.contains(order[i].id) { return false }
        }
        return true
    }

    static func isCompleted(_ level: JourneyLevel, progress: UserJourneyProgress) -> Bool {
        progress.completedLevelIDs.contains(level.id)
    }

    /// Percentage [0, 1] of levels the user has finished overall.
    static func overallProgress(_ progress: UserJourneyProgress) -> Double {
        let total = JourneyContent.allLevelsInOrder.count
        guard total > 0 else { return 0 }
        return Double(progress.completedLevelIDs.count) / Double(total)
    }

    // MARK: - Streak

    /// Current workout streak (consecutive calendar days ending today or
    /// yesterday that include at least one accepted workout session).
    static func currentStreak(sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let accepted = sessions.filter {
            $0.statusRaw == SessionStatus.completed.rawValue && $0.repCount > 0
        }
        guard !accepted.isEmpty else { return 0 }

        let workoutDays: Set<Date> = Set(
            accepted.map { calendar.startOfDay(for: $0.startedAt) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if !workoutDays.contains(cursor) {
            // Don't penalise the user if they haven't moved yet today —
            // the streak is still "alive" as long as yesterday had a
            // workout. We start counting from yesterday in that case.
            guard let yesterday = calendar.date(
                byAdding: .day, value: -1, to: cursor
            ) else { return 0 }
            cursor = yesterday
        }
        while workoutDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(
                byAdding: .day, value: -1, to: cursor
            ) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Challenge validation

    /// Check whether a freshly-finished `WorkoutSession` satisfies the
    /// current level's challenge. Used by SessionSummaryView right after
    /// a workout to decide whether to mark the level complete.
    static func evaluate(
        challenge: JourneyChallenge,
        session: WorkoutSession,
        allSessions: [WorkoutSession]
    ) -> Bool {
        switch challenge {
        case .reps(let exercise, let count):
            return session.exerciseTypeRaw == exercise.rawValue
                && session.repCount >= count
        case .mixed(let steps):
            // v1: a mixed challenge is satisfied by a SINGLE session that
            // meets ANY one of the steps. Real multi-exercise sessions
            // aren't something our camera flow supports yet, so to keep
            // the promise honest we accept the session if the user has
            // completed sub-sessions across *today* that cover every
            // step. This is evaluated via `allSessions`.
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todaySessions = allSessions.filter {
                $0.statusRaw == SessionStatus.completed.rawValue
                    && calendar.startOfDay(for: $0.startedAt) == today
            }
            return steps.allSatisfy { step in
                todaySessions.contains { s in
                    s.exerciseTypeRaw == step.exercise.rawValue
                        && s.repCount >= step.count
                }
            }
        case .session(let minutes):
            guard let ended = session.finishedAt else { return false }
            return ended.timeIntervalSince(session.startedAt) >= minutes * 60
        case .earn(let minutes):
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let earnedToday = allSessions
                .filter { calendar.startOfDay(for: $0.startedAt) == today }
                .reduce(0.0) { $0 + $1.earnedMinutes }
            return Int(earnedToday) >= minutes
        case .streak(let days):
            return currentStreak(sessions: allSessions) >= days
        }
    }

    // MARK: - Completion

    /// Mark a level complete, award XP + bonus minutes + badge, and
    /// persist. Idempotent: calling twice on the same level is a no-op.
    /// Returns a `CompletionResult` so the UI can show the right
    /// celebration sheet (new badge, next level, etc).
    struct CompletionResult {
        let levelCompleted: JourneyLevel
        let newlyAwardedBadgeId: String?
        let nextLevel: JourneyLevel?
    }

    @discardableResult
    static func completeLevel(
        _ level: JourneyLevel,
        progress: UserJourneyProgress,
        earnedBadges: [EarnedBadge],
        modelContext: ModelContext
    ) -> CompletionResult {
        guard !progress.completedLevelIDs.contains(level.id) else {
            return CompletionResult(
                levelCompleted: level,
                newlyAwardedBadgeId: nil,
                nextLevel: nextLevel(after: level, progress: progress)
            )
        }

        progress.completedLevelIDs.append(level.id)
        progress.totalXP += level.rewardXP
        progress.updatedAt = Date()

        // Bonus minutes enter the regular UnlockCredit pool so they can
        // be redeemed exactly like workout-earned minutes. We use a
        // synthetic UUID for `sourceSessionId` — the field isn't
        // referentially enforced and nothing else reads it.
        if level.rewardBonusMinutes > 0 {
            let credit = UnlockCredit(
                earnedMinutes: Double(level.rewardBonusMinutes),
                sourceSessionId: UUID()
            )
            modelContext.insert(credit)
        }

        // Badge award — idempotent by badge id.
        var awardedBadgeId: String?
        if let badgeId = level.badgeId,
           !earnedBadges.contains(where: { $0.badgeId == badgeId }) {
            let earned = EarnedBadge(badgeId: badgeId)
            modelContext.insert(earned)
            awardedBadgeId = badgeId
        }

        try? modelContext.save()

        return CompletionResult(
            levelCompleted: level,
            newlyAwardedBadgeId: awardedBadgeId,
            nextLevel: nextLevel(after: level, progress: progress)
        )
    }

    private static func nextLevel(
        after level: JourneyLevel,
        progress: UserJourneyProgress
    ) -> JourneyLevel? {
        let order = JourneyContent.allLevelsInOrder
        guard let idx = order.firstIndex(where: { $0.id == level.id }),
              idx + 1 < order.count else { return nil }
        return order[idx + 1]
    }
}
