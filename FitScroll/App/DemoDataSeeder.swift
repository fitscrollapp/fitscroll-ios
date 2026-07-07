import Foundation
import SwiftData

#if DEBUG
/// Seeds rich, good-looking demo data for App Store screenshot captures.
/// Activated by launching with `-demodata` (implies the `-uitesting` gate
/// bypass too). Idempotent per launch: wipes workout data and reseeds so the
/// numbers are always the same.
@MainActor
enum DemoDataSeeder {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.localizedCaseInsensitiveContains("demodata") }
    }

    static func seedIfRequested(context: ModelContext) {
        guard isRequested else { return }

        // Fresh slate.
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: UserJourneyProgress.self)

        let cal = Calendar.current
        let now = Date()

        // Today's sessions are anchored to "now" (not wall-clock hours) so a
        // capture right after midnight never shows them in the future — and
        // clamped to stay within today so they always feed the "earned
        // today" ring, even minutes past midnight.
        let startOfDay = cal.startOfDay(for: now)
        for (offsetHours, exercise, reps) in [(-2.0, ExerciseType.pushUp, 22), (-5.0, .squat, 20)] {
            let clampFloor = startOfDay.addingTimeInterval(offsetHours == -2.0 ? 1200 : 300)
            let start = max(now.addingTimeInterval(offsetHours * 3600), clampFloor)
            context.insert(WorkoutSession(
                exerciseType: exercise,
                repCount: reps,
                earnedMinutes: Double(reps),
                averageConfidence: 0.94,
                startedAt: start,
                finishedAt: start.addingTimeInterval(Double(reps) * 4),
                status: .completed
            ))
        }

        /// (daysAgo, hour, exercise, reps)
        let plan: [(Int, Int, ExerciseType, Int)] = [
            // A committed week (7-day streak → Streak Hero badge).
            (1, 9, .pushUp, 30), (1, 18, .jumpingJacks, 35),
            (2, 8, .squat, 28), (2, 19, .lunge, 16),
            (3, 7, .pushUp, 26), (3, 17, .squat, 24),
            (4, 9, .jumpingJacks, 40),
            (5, 8, .pushUp, 34), (5, 18, .lunge, 18),
            (6, 9, .squat, 30), (6, 20, .pushUp, 28),
            (7, 8, .jumpingJacks, 32),
            // Older history so the 30-day chart has shape.
            (9, 9, .pushUp, 24), (11, 18, .squat, 26),
            (13, 8, .jumpingJacks, 30), (16, 9, .lunge, 14),
            (19, 18, .pushUp, 20), (23, 9, .squat, 22),
        ]

        for (daysAgo, hour, exercise, reps) in plan {
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: now),
                  let start = cal.date(bySettingHour: hour, minute: 12, second: 0, of: day)
            else { continue }
            let session = WorkoutSession(
                exerciseType: exercise,
                repCount: reps,
                earnedMinutes: Double(reps),
                averageConfidence: 0.94,
                startedAt: start,
                finishedAt: start.addingTimeInterval(Double(reps) * 4),
                status: .completed
            )
            context.insert(session)
        }

        // Level / XP chip on the dashboard.
        context.insert(UserJourneyProgress(
            completedLevelIDs: ["l1", "l2", "l3", "l4"],
            totalXP: 860
        ))

        try? context.save()

        // Leaderboard identity + a lively notification bell.
        UserDefaults.standard.set("alex", forKey: "fitscroll.username")
        seedInbox()
    }

    private static func seedInbox() {
        struct Item: Codable {
            let id: String
            let from: String
            let exerciseRaw: String
            let target: Int
            let receivedAt: Date
            var status: String
            var isRead: Bool
        }
        let items = [
            Item(id: "DEMO0001", from: "Elena", exerciseRaw: "pushUp", target: 30,
                 receivedAt: Date().addingTimeInterval(-1_800), status: "pending", isRead: false),
            Item(id: "DEMO0002", from: "Diego", exerciseRaw: "squat", target: 25,
                 receivedAt: Date().addingTimeInterval(-86_400), status: "accepted", isRead: true),
        ]
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "fitscroll.challenge.inbox")
        }
    }
}
#endif
