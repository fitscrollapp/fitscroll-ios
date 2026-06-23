import SwiftUI
import SwiftData

struct JourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressRecords: [UserJourneyProgress]
    @Query private var earnedBadges: [EarnedBadge]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var selectedLevel: JourneyLevel?
    @State private var showBadges = false

    private var progress: UserJourneyProgress {
        if let existing = progressRecords.first { return existing }
        let fresh = UserJourneyProgress()
        modelContext.insert(fresh)
        try? modelContext.save()
        return fresh
    }

    private var streak: Int {
        JourneyService.currentStreak(sessions: sessions)
    }

    private var currentLevelId: String? {
        JourneyService.currentLevel(progress: progress)?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                    statsCard
                    milestonesSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBadges = true
                    } label: {
                        Image(systemName: "rosette")
                    }
                }
            }
            .sheet(item: $selectedLevel) { level in
                LevelDetailSheet(level: level, progress: progress)
            }
            .sheet(isPresented: $showBadges) {
                BadgesView()
            }
        }
    }

    // MARK: - Derived values

    private var levelNumber: Int { progress.completedLevelIDs.count + 1 }

    /// XP target for the bar — the next 100-XP boundary above the current
    /// total, so the label reads like "225 / 300 XP".
    private var xpGoal: Int { (progress.totalXP / 100 + 1) * 100 }

    private var xpProgress: Double {
        guard xpGoal > 0 else { return 0 }
        return min(1, Double(progress.totalXP) / Double(xpGoal))
    }

    private enum MilestoneState { case completed, current, upcoming, locked }

    private func state(for level: JourneyLevel) -> MilestoneState {
        if JourneyService.isCompleted(level, progress: progress) { return .completed }
        if level.id == currentLevelId { return .current }
        if JourneyService.isUnlocked(level, progress: progress) { return .upcoming }
        return .locked
    }

    /// The full journey — every level in order. Completed and current levels
    /// are highlighted; upcoming ones show locked so the whole path is
    /// visible up front rather than appearing only as you progress.
    private var milestones: [JourneyLevel] {
        JourneyContent.allLevelsInOrder
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Your Journey")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
            Text("Every rep brings you closer.")
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: 0) {
                statColumn(icon: "flame.fill", value: "\(streak)", label: "day streak", color: DS.Colors.accent)
                statDivider
                statColumn(icon: "bolt.fill", value: "\(progress.totalXP)", label: "XP", color: DS.Colors.neon)
                statDivider
                statColumn(icon: "checkmark.seal.fill", value: "\(levelNumber)", label: "Level", color: DS.Colors.secondary)
            }

            VStack(spacing: DS.Spacing.xs) {
                HStack {
                    Spacer()
                    Text("\(progress.totalXP) / \(xpGoal) XP")
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .monospacedDigit()
                }
                ProgressView(value: xpProgress)
                    .tint(DS.Colors.neon)
            }
        }
        .padding(DS.Spacing.md)
        .dsCard()
    }

    private func statColumn(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.border)
            .frame(width: 1, height: 32)
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Milestones")
                .font(.headline)
                .foregroundColor(DS.Colors.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { idx, level in
                    milestoneRow(level, isLast: idx == milestones.count - 1)
                }
            }
        }
    }

    @ViewBuilder
    private func milestoneRow(_ level: JourneyLevel, isLast: Bool) -> some View {
        let st = state(for: level)
        Button {
            selectedLevel = level
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                // Timeline column: node + connecting line.
                VStack(spacing: 0) {
                    milestoneNode(st, level: level)
                    if !isLast {
                        Rectangle()
                            .fill(st == .completed ? DS.Colors.neon.opacity(0.6) : DS.Colors.border)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 30)

                // Content (current level gets a highlighted box).
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(st == .locked ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                    Text(subtitle(for: st, level: level))
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, st == .current ? DS.Spacing.md : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                        .fill(st == .current ? DS.Colors.neon.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                        .stroke(st == .current ? DS.Colors.neon : Color.clear, lineWidth: 1.5)
                )
                .padding(.bottom, DS.Spacing.md)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func milestoneNode(_ st: MilestoneState, level: JourneyLevel) -> some View {
        ZStack {
            Circle()
                .fill(nodeFill(st))
                .frame(width: 30, height: 30)
            Circle()
                .stroke(nodeStroke(st), lineWidth: 2)
                .frame(width: 30, height: 30)
            Image(systemName: nodeIcon(st))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(nodeIconColor(st))
        }
    }

    private func nodeFill(_ st: MilestoneState) -> Color {
        switch st {
        case .completed: return DS.Colors.neon
        case .current:   return DS.Colors.neon.opacity(0.15)
        case .upcoming:  return DS.Colors.secondary
        case .locked:    return DS.Colors.cardBackground
        }
    }

    private func nodeStroke(_ st: MilestoneState) -> Color {
        switch st {
        case .current: return DS.Colors.neon
        case .locked:  return DS.Colors.border
        default:       return .clear
        }
    }

    private func nodeIcon(_ st: MilestoneState) -> String {
        switch st {
        case .completed: return "checkmark"
        case .current:   return "bolt.fill"
        case .upcoming:  return "star.fill"
        case .locked:    return "lock.fill"
        }
    }

    private func nodeIconColor(_ st: MilestoneState) -> Color {
        switch st {
        case .completed: return DS.Colors.background
        case .current:   return DS.Colors.neon
        case .upcoming:  return .white
        case .locked:    return DS.Colors.textSecondary
        }
    }

    private func subtitle(for st: MilestoneState, level: JourneyLevel) -> String {
        switch st {
        case .completed: return "Completed"
        case .current:   return "In progress · \(level.challenge.summary)"
        case .upcoming:  return level.challenge.summary
        case .locked:    return "Locked"
        }
    }
}

// MARK: - Level detail sheet

struct LevelDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let level: JourneyLevel
    let progress: UserJourneyProgress

    @State private var navigateToWorkout: ExerciseType?

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                Spacer().frame(height: DS.Spacing.lg)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.10),
                                    Color(red: 0.95, green: 0.30, blue: 0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: .orange.opacity(0.5), radius: 20)
                    Image(systemName: level.isBoss ? "crown.fill" : iconFor(level.challenge))
                        .font(.system(size: 44, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(spacing: DS.Spacing.xs) {
                    if level.isBoss {
                        Text("BOSS LEVEL")
                            .font(.caption)
                            .fontWeight(.black)
                            .foregroundColor(.yellow)
                    }
                    Text(level.title)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(level.challenge.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                rewardRow

                Spacer()

                if let exercise = primaryExercise() {
                    PrimaryButton(title: "Start") {
                        navigateToWorkout = exercise
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                } else {
                    passiveChallengeExplainer
                        .padding(.horizontal, DS.Spacing.lg)
                }

                Button("Close") { dismiss() }
                    .padding(.bottom, DS.Spacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigateToWorkout) { exercise in
                CameraWorkoutView(exerciseType: exercise)
            }
        }
    }

    private var rewardRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            rewardPill(icon: "star.fill", label: "+\(level.rewardXP) XP", color: .yellow)
            rewardPill(
                icon: "clock.fill",
                label: "+\(level.rewardBonusMinutes) min",
                color: .orange
            )
            if let badgeId = level.badgeId, let badge = JourneyContent.badge(id: badgeId) {
                rewardPill(icon: badge.iconSystemName, label: badge.title, color: .white)
            }
        }
    }

    private func rewardPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            Text(label).font(.caption).fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }

    private var passiveChallengeExplainer: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Do your daily workouts — this level completes on its own when the goal is met.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Go to Workouts") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Returns the exercise this level's Start button should jump into,
    /// or nil for streak / earn / multi-exercise mixed challenges.
    private func primaryExercise() -> ExerciseType? {
        switch level.challenge {
        case .reps(let exercise, _):
            return exercise
        case .mixed(let steps):
            // Start with the first listed step. User may need to run
            // several sessions to finish a mixed level.
            return steps.first?.exercise
        case .session:
            return .pushUp // default to push-up for a generic session
        case .earn, .streak:
            return nil
        }
    }

    private func iconFor(_ challenge: JourneyChallenge) -> String {
        switch challenge {
        case .reps(let exercise, _): return exercise.iconName
        case .mixed: return "square.stack.3d.up.fill"
        case .session: return "timer"
        case .earn: return "clock.badge.checkmark"
        case .streak: return "flame.fill"
        }
    }
}

// MARK: - Journey completion sheet

struct JourneyCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let level: JourneyLevel
    let badge: Badge?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.07, blue: 0.22),
                        Color(red: 0.12, green: 0.20, blue: 0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    Image(systemName: level.isBoss ? "crown.fill" : "checkmark.seal.fill")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.20),
                                    Color(red: 1.0, green: 0.55, blue: 0.10),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(level.isBoss ? "Boss Defeated!" : "Level Complete!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(level.title)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))

                    HStack(spacing: DS.Spacing.md) {
                        rewardCard(
                            icon: "star.fill",
                            label: "+\(level.rewardXP)",
                            caption: "XP",
                            tint: .yellow
                        )
                        rewardCard(
                            icon: "clock.fill",
                            label: "+\(level.rewardBonusMinutes)",
                            caption: "min bonus",
                            tint: .orange
                        )
                    }

                    if let badge = badge {
                        VStack(spacing: DS.Spacing.sm) {
                            Text("NEW BADGE")
                                .font(.caption2)
                                .fontWeight(.black)
                                .foregroundColor(.yellow)
                            HStack(spacing: DS.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: badge.colorHex) ?? .orange)
                                        .frame(width: 56, height: 56)
                                    Image(systemName: badge.iconSystemName)
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(badge.title)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(badge.description)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(DS.Spacing.md)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(DS.Corner.medium)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    Spacer()

                    Button("Continue") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.10),
                                Color(red: 0.95, green: 0.30, blue: 0.25),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(DS.Corner.large)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl)
                }

                ConfettiView()
                    .ignoresSafeArea()
            }
            .navigationBarHidden(true)
        }
    }

    private func rewardCard(
        icon: String,
        label: String,
        caption: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(caption)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.lg)
        .background(Color.white.opacity(0.08))
        .cornerRadius(DS.Corner.medium)
    }
}

// MARK: - Badges view

struct BadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var earned: [EarnedBadge]

    private var earnedIds: Set<String> {
        Set(earned.map(\.badgeId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let cols = [
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                    GridItem(.flexible(), spacing: DS.Spacing.md),
                ]
                LazyVGrid(columns: cols, spacing: DS.Spacing.lg) {
                    ForEach(JourneyContent.badges) { badge in
                        BadgeTile(
                            badge: badge,
                            isEarned: earnedIds.contains(badge.id)
                        )
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct BadgeTile: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(
                        isEarned
                            ? (Color(hex: badge.colorHex) ?? .orange)
                            : Color.white.opacity(0.08)
                    )
                    .frame(width: 74, height: 74)
                Image(systemName: badge.iconSystemName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isEarned ? .white : .secondary)
            }
            .grayscale(isEarned ? 0 : 0.9)
            Text(badge.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(isEarned ? 1.0 : 0.5)
    }
}

// MARK: - Color(hex:) helper (scoped)

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
