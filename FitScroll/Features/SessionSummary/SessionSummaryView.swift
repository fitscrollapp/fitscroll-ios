import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Query private var journeyProgress: [UserJourneyProgress]
    @Query private var earnedBadges: [EarnedBadge]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]

    let session: WorkoutSession
    /// Called when the user taps "Apply Unlock" or "Back to Dashboard".
    /// The parent (CameraWorkoutView) uses this to also dismiss itself so
    /// the user returns all the way to the dashboard instead of being
    /// stranded on the camera view under a dismissed summary sheet.
    var onFinish: () -> Void = {}
    @State private var animateStats = false
    @State private var completedLevel: JourneyLevel?
    @State private var awardedBadge: Badge?

    private var didEarnReps: Bool { session.repCount > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                summaryContent
                if didEarnReps {
                    ConfettiView()
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var summaryContent: some View {
            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DS.Colors.success)
                    .scaleEffect(animateStats ? 1.0 : 0.5)
                    .animation(DS.Animation.spring, value: animateStats)

                Text(Strings.Summary.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Stats
                HStack(spacing: DS.Spacing.lg) {
                    StatCard(
                        title: Strings.Summary.totalReps,
                        value: "\(session.repCount)",
                        icon: "repeat",
                        color: DS.Colors.primary
                    )
                    StatCard(
                        title: Strings.Summary.earnedMinutes,
                        value: TimeFormatter.formatMinutes(session.earnedMinutes),
                        icon: "clock.fill",
                        color: DS.Colors.accent
                    )
                }

                HStack(spacing: DS.Spacing.lg) {
                    StatCard(
                        title: Strings.Summary.avgConfidence,
                        value: String(format: "%.0f%%", session.averageConfidence * 100),
                        icon: "target",
                        color: DS.Colors.success
                    )
                    StatCard(
                        title: Strings.Summary.duration,
                        value: durationText,
                        icon: "timer",
                        color: DS.Colors.secondary
                    )
                }

                // Motivational message
                Text(String(format: Strings.Summary.unlockMessage, Int(session.earnedMinutes)))
                    .font(.headline)
                    .foregroundColor(DS.Colors.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: DS.Spacing.md) {
                    if session.earnedMinutes > 0 {
                        PrimaryButton(title: Strings.Summary.applyUnlock) {
                            Task {
                                await screenTimeService.applyTemporaryUnlock(durationMinutes: session.earnedMinutes)
                                dismiss()
                                onFinish()
                            }
                        }
                    }

                    Button {
                        dismiss()
                        onFinish()
                    } label: {
                        Text(Strings.Summary.backToDashboard)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(DS.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.primary.opacity(0.12))
                            .cornerRadius(DS.Corner.medium)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
            .padding(DS.Spacing.lg)
            .onAppear {
                withAnimation {
                    animateStats = true
                }
                if didEarnReps {
                    SoundManager.sessionVictory()
                    checkJourneyProgress()
                }
            }
            .sheet(item: $completedLevel) { level in
                JourneyCompletionSheet(
                    level: level,
                    badge: awardedBadge
                )
            }
    }

    /// Called after the session lands. If the user's current Journey
    /// level is satisfied by this session, mark it complete + award the
    /// bonus, then show a celebration sheet on top of the summary.
    private func checkJourneyProgress() {
        let progress: UserJourneyProgress
        if let existing = journeyProgress.first {
            progress = existing
        } else {
            progress = UserJourneyProgress()
            modelContext.insert(progress)
        }

        guard let currentLevel = JourneyService.currentLevel(progress: progress) else {
            return
        }
        // Include this session in the lookup set so mixed / session
        // challenges see it (SwiftData may not have published the
        // insert into `allSessions` yet at the moment onAppear fires).
        var sessionsForEval = allSessions
        if !sessionsForEval.contains(where: { $0.id == session.id }) {
            sessionsForEval.insert(session, at: 0)
        }
        let satisfied = JourneyService.evaluate(
            challenge: currentLevel.challenge,
            session: session,
            allSessions: sessionsForEval
        )
        guard satisfied else { return }

        let result = JourneyService.completeLevel(
            currentLevel,
            progress: progress,
            earnedBadges: earnedBadges,
            modelContext: modelContext
        )
        completedLevel = result.levelCompleted
        if let badgeId = result.newlyAwardedBadgeId {
            awardedBadge = JourneyContent.badge(id: badgeId)
        }
    }

    private var durationText: String {
        guard let finished = session.finishedAt else { return "--" }
        let duration = finished.timeIntervalSince(session.startedAt)
        return TimeFormatter.formatDuration(seconds: duration)
    }
}
