import Foundation
import SwiftData

/// Persistent state for a user's Journey progress. Kept separate from
/// UserSettings so we can reset progress without nuking preferences.
@Model
final class UserJourneyProgress {
    @Attribute(.unique) var id: UUID
    /// IDs (from `JourneyContent`) of the levels the user has finished.
    var completedLevelIDs: [String]
    /// Running XP total. Not visible as a bar across the whole app
    /// yet but shown in the Journey header.
    var totalXP: Int
    /// Last rollover day start (midnight) so we can reset any
    /// single-day earn-challenge trackers when the user returns.
    var lastEarnCheckDay: Date?
    /// Minutes earned today, accumulated from WorkoutSession entries.
    /// Kept on the progress record so we don't rescan sessions on every
    /// tap. Main use: earn-minutes challenge validation.
    var minutesEarnedToday: Double
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        completedLevelIDs: [String] = [],
        totalXP: Int = 0,
        lastEarnCheckDay: Date? = nil,
        minutesEarnedToday: Double = 0
    ) {
        self.id = id
        self.completedLevelIDs = completedLevelIDs
        self.totalXP = totalXP
        self.lastEarnCheckDay = lastEarnCheckDay
        self.minutesEarnedToday = minutesEarnedToday
        self.updatedAt = Date()
    }
}

/// Persistent list of earned badges. Kept separate so users keep
/// their badges across Journey resets.
@Model
final class EarnedBadge {
    @Attribute(.unique) var id: UUID
    var badgeId: String
    var earnedAt: Date

    init(badgeId: String, earnedAt: Date = Date()) {
        self.id = UUID()
        self.badgeId = badgeId
        self.earnedAt = earnedAt
    }
}
