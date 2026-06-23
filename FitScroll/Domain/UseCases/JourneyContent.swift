import Foundation

/// Static content catalog for the Journey system. Content lives in
/// code on purpose — it's small, needs to be localized alongside the
/// app, and doesn't change without a new release.
enum JourneyContent {

    // MARK: - Sections

    static let sections: [JourneySection] = [
        JourneySection(
            id: "sec-first-week",
            index: 0,
            title: "First Week",
            tagline: "Move a little, win a little.",
            colorHex: "#EF4723",
            unlocksExercise: nil
        ),
        JourneySection(
            id: "sec-building-habit",
            index: 1,
            title: "Building the Habit",
            tagline: "Show up again. And again.",
            colorHex: "#F5A623",
            unlocksExercise: .jumpingJacks
        ),
        JourneySection(
            id: "sec-break-loop",
            index: 2,
            title: "Break the Loop",
            tagline: "Earn your scrolls with sweat.",
            colorHex: "#00E5D1",
            unlocksExercise: .lunge
        ),
        JourneySection(
            id: "sec-hardened",
            index: 3,
            title: "Hardened",
            tagline: "No more easy way out.",
            colorHex: "#5B2A86",
            unlocksExercise: nil
        ),
    ]

    // MARK: - Levels

    static let levels: [JourneyLevel] = {
        var all: [JourneyLevel] = []

        // --- Section 1: First Week ---
        all.append(contentsOf: [
            JourneyLevel(
                id: "L1.1", sectionId: "sec-first-week", index: 0,
                title: "First Push-Up",
                challenge: .reps(exercise: .pushUp, count: 3),
                rewardXP: 10, rewardBonusMinutes: 2,
                badgeId: "badge-first-rep", isBoss: false
            ),
            JourneyLevel(
                id: "L1.2", sectionId: "sec-first-week", index: 1,
                title: "Squat Up",
                challenge: .reps(exercise: .squat, count: 3),
                rewardXP: 10, rewardBonusMinutes: 2,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L1.3", sectionId: "sec-first-week", index: 2,
                title: "Warm Engine",
                challenge: .reps(exercise: .pushUp, count: 5),
                rewardXP: 15, rewardBonusMinutes: 3,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L1.4", sectionId: "sec-first-week", index: 3,
                title: "Two Moves",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 3),
                    .init(exercise: .squat, count: 3),
                ]),
                rewardXP: 20, rewardBonusMinutes: 4,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L1.5", sectionId: "sec-first-week", index: 4,
                title: "Stretch a Minute",
                challenge: .session(minutes: 1),
                rewardXP: 20, rewardBonusMinutes: 4,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L1.6", sectionId: "sec-first-week", index: 5,
                title: "Ten Push-Ups",
                challenge: .reps(exercise: .pushUp, count: 10),
                rewardXP: 25, rewardBonusMinutes: 5,
                badgeId: "badge-10-pushups", isBoss: false
            ),
            JourneyLevel(
                id: "L1.BOSS", sectionId: "sec-first-week", index: 6,
                title: "First Boss",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 5),
                    .init(exercise: .squat, count: 5),
                    .init(exercise: .pushUp, count: 5),
                ]),
                rewardXP: 50, rewardBonusMinutes: 10,
                badgeId: "badge-first-boss", isBoss: true
            ),
        ])

        // --- Section 2: Building the Habit ---
        all.append(contentsOf: [
            JourneyLevel(
                id: "L2.1", sectionId: "sec-building-habit", index: 0,
                title: "Jump In",
                challenge: .reps(exercise: .jumpingJacks, count: 10),
                rewardXP: 20, rewardBonusMinutes: 4,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L2.2", sectionId: "sec-building-habit", index: 1,
                title: "Back-to-Back",
                challenge: .streak(days: 2),
                rewardXP: 25, rewardBonusMinutes: 5,
                badgeId: "badge-streak-2", isBoss: false
            ),
            JourneyLevel(
                id: "L2.3", sectionId: "sec-building-habit", index: 2,
                title: "Cardio Burst",
                challenge: .reps(exercise: .jumpingJacks, count: 20),
                rewardXP: 25, rewardBonusMinutes: 5,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L2.4", sectionId: "sec-building-habit", index: 3,
                title: "Triple Mix",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 5),
                    .init(exercise: .squat, count: 5),
                    .init(exercise: .jumpingJacks, count: 5),
                ]),
                rewardXP: 30, rewardBonusMinutes: 6,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L2.5", sectionId: "sec-building-habit", index: 4,
                title: "Two Minutes",
                challenge: .session(minutes: 2),
                rewardXP: 30, rewardBonusMinutes: 6,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L2.6", sectionId: "sec-building-habit", index: 5,
                title: "Earn It",
                challenge: .earn(minutes: 10),
                rewardXP: 30, rewardBonusMinutes: 5,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L2.BOSS", sectionId: "sec-building-habit", index: 6,
                title: "Habit Boss",
                challenge: .streak(days: 3),
                rewardXP: 75, rewardBonusMinutes: 15,
                badgeId: "badge-streak-3", isBoss: true
            ),
        ])

        // --- Section 3: Break the Loop ---
        all.append(contentsOf: [
            JourneyLevel(
                id: "L3.1", sectionId: "sec-break-loop", index: 0,
                title: "Enter the Lunge",
                challenge: .reps(exercise: .lunge, count: 5),
                rewardXP: 25, rewardBonusMinutes: 5,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L3.2", sectionId: "sec-break-loop", index: 1,
                title: "Deeper",
                challenge: .reps(exercise: .lunge, count: 10),
                rewardXP: 30, rewardBonusMinutes: 6,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L3.3", sectionId: "sec-break-loop", index: 2,
                title: "Full House",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 5),
                    .init(exercise: .squat, count: 5),
                    .init(exercise: .jumpingJacks, count: 5),
                    .init(exercise: .lunge, count: 5),
                ]),
                rewardXP: 40, rewardBonusMinutes: 8,
                badgeId: "badge-all-four", isBoss: false
            ),
            JourneyLevel(
                id: "L3.4", sectionId: "sec-break-loop", index: 3,
                title: "Endurance",
                challenge: .session(minutes: 3),
                rewardXP: 40, rewardBonusMinutes: 8,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L3.5", sectionId: "sec-break-loop", index: 4,
                title: "Earn Big",
                challenge: .earn(minutes: 20),
                rewardXP: 40, rewardBonusMinutes: 8,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L3.6", sectionId: "sec-break-loop", index: 5,
                title: "Steady",
                challenge: .streak(days: 5),
                rewardXP: 50, rewardBonusMinutes: 10,
                badgeId: "badge-streak-5", isBoss: false
            ),
            JourneyLevel(
                id: "L3.BOSS", sectionId: "sec-break-loop", index: 6,
                title: "Loop Breaker",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 10),
                    .init(exercise: .squat, count: 10),
                    .init(exercise: .jumpingJacks, count: 10),
                    .init(exercise: .lunge, count: 10),
                ]),
                rewardXP: 100, rewardBonusMinutes: 20,
                badgeId: "badge-loop-breaker", isBoss: true
            ),
        ])

        // --- Section 4: Hardened ---
        all.append(contentsOf: [
            JourneyLevel(
                id: "L4.1", sectionId: "sec-hardened", index: 0,
                title: "Thirty",
                challenge: .reps(exercise: .pushUp, count: 30),
                rewardXP: 60, rewardBonusMinutes: 12,
                badgeId: "badge-30-pushups", isBoss: false
            ),
            JourneyLevel(
                id: "L4.2", sectionId: "sec-hardened", index: 1,
                title: "Thirty Squats",
                challenge: .reps(exercise: .squat, count: 30),
                rewardXP: 60, rewardBonusMinutes: 12,
                badgeId: "badge-30-squats", isBoss: false
            ),
            JourneyLevel(
                id: "L4.3", sectionId: "sec-hardened", index: 2,
                title: "Five-Minute Burn",
                challenge: .session(minutes: 5),
                rewardXP: 80, rewardBonusMinutes: 15,
                badgeId: nil, isBoss: false
            ),
            JourneyLevel(
                id: "L4.4", sectionId: "sec-hardened", index: 3,
                title: "Iron Will",
                challenge: .streak(days: 7),
                rewardXP: 100, rewardBonusMinutes: 20,
                badgeId: "badge-streak-7", isBoss: false
            ),
            JourneyLevel(
                id: "L4.BOSS", sectionId: "sec-hardened", index: 4,
                title: "Hardened Boss",
                challenge: .mixed(steps: [
                    .init(exercise: .pushUp, count: 20),
                    .init(exercise: .squat, count: 20),
                    .init(exercise: .jumpingJacks, count: 20),
                    .init(exercise: .lunge, count: 20),
                ]),
                rewardXP: 200, rewardBonusMinutes: 30,
                badgeId: "badge-hardened", isBoss: true
            ),
        ])

        return all
    }()

    // MARK: - Badges

    static let badges: [Badge] = [
        Badge(
            id: "badge-first-rep",
            title: "First Rep",
            description: "You moved. That's the hardest part.",
            iconSystemName: "sparkles",
            colorHex: "#F5A623"
        ),
        Badge(
            id: "badge-10-pushups",
            title: "Ten Push-Ups",
            description: "Ten in one go. Nice.",
            iconSystemName: "figure.strengthtraining.traditional",
            colorHex: "#EF4723"
        ),
        Badge(
            id: "badge-first-boss",
            title: "First Boss",
            description: "You took down a boss level.",
            iconSystemName: "crown.fill",
            colorHex: "#FFD65C"
        ),
        Badge(
            id: "badge-streak-2",
            title: "Back-to-Back",
            description: "Two days in a row.",
            iconSystemName: "flame.fill",
            colorHex: "#F5A623"
        ),
        Badge(
            id: "badge-streak-3",
            title: "Three-Day Streak",
            description: "A habit is forming.",
            iconSystemName: "flame.fill",
            colorHex: "#EF4723"
        ),
        Badge(
            id: "badge-streak-5",
            title: "Five-Day Streak",
            description: "You're not stopping now.",
            iconSystemName: "flame.fill",
            colorHex: "#EF4723"
        ),
        Badge(
            id: "badge-streak-7",
            title: "Iron Will",
            description: "A full week. Untouchable.",
            iconSystemName: "flame.fill",
            colorHex: "#C62D0F"
        ),
        Badge(
            id: "badge-all-four",
            title: "All-Rounder",
            description: "All four exercises in one session.",
            iconSystemName: "star.fill",
            colorHex: "#00E5D1"
        ),
        Badge(
            id: "badge-loop-breaker",
            title: "Loop Breaker",
            description: "You broke the dopamine loop.",
            iconSystemName: "scissors",
            colorHex: "#00E5D1"
        ),
        Badge(
            id: "badge-30-pushups",
            title: "Thirty Push-Ups",
            description: "30 in one session. Animal.",
            iconSystemName: "figure.strengthtraining.traditional",
            colorHex: "#EF4723"
        ),
        Badge(
            id: "badge-30-squats",
            title: "Thirty Squats",
            description: "30 squats, no rest.",
            iconSystemName: "figure.strengthtraining.functional",
            colorHex: "#EF4723"
        ),
        Badge(
            id: "badge-hardened",
            title: "Hardened",
            description: "The end of the Journey. For now.",
            iconSystemName: "shield.fill",
            colorHex: "#5B2A86"
        ),
    ]

    static func section(id: String) -> JourneySection? {
        sections.first { $0.id == id }
    }

    static func level(id: String) -> JourneyLevel? {
        levels.first { $0.id == id }
    }

    static func badge(id: String) -> Badge? {
        badges.first { $0.id == id }
    }

    static func levels(in sectionId: String) -> [JourneyLevel] {
        levels.filter { $0.sectionId == sectionId }
            .sorted { $0.index < $1.index }
    }

    /// Linear order used to compute unlock state — the whole path.
    static var allLevelsInOrder: [JourneyLevel] {
        sections.sorted { $0.index < $1.index }.flatMap { section in
            levels(in: section.id)
        }
    }
}
