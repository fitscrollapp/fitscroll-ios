import SwiftUI
import SwiftData
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var credits: [UnlockCredit]
    @Query private var journeyRecords: [UserJourneyProgress]
    @Binding var showUnlockSession: Bool
    @State private var showAppPicker = false

    /// Daily "earn" goal the ring fills toward. Purely a visual target.
    private let dailyGoalMinutes: Double = 60

    init(showUnlockSession: Binding<Bool> = .constant(false)) {
        self._showUnlockSession = showUnlockSession
    }

    private var todayEarnedMinutes: Double {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDateInToday($0.startedAt) && $0.statusRaw == SessionStatus.completed.rawValue }
            .reduce(0) { $0 + $1.earnedMinutes }
    }

    private var ringProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1, todayEarnedMinutes / dailyGoalMinutes)
    }

    private var recentSessions: [WorkoutSession] {
        Array(sessions.prefix(5))
    }

    private var lockedItemCount: Int {
        screenTimeService.selectedApps.applicationTokens.count +
            screenTimeService.selectedApps.categoryTokens.count
    }

    private var streak: Int {
        JourneyService.currentStreak(sessions: sessions)
    }

    private var journeyProgress: UserJourneyProgress? { journeyRecords.first }

    private var totalXP: Int { journeyProgress?.totalXP ?? 0 }

    private var levelNumber: Int { (journeyProgress?.completedLevelIDs.count ?? 0) + 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    heroSection
                    chipsRow
                    unlockButton
                    recentSessionsSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle(Strings.Dashboard.title)
            .navigationBarTitleDisplayMode(.inline)
            // Tapping the "apps protected" chip jumps straight into the system
            // picker — which
            // itself shows which apps/categories are selected — instead of
            // an intermediate summary screen.
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $screenTimeService.selectedApps
            )
            .onChange(of: showAppPicker) { _, isShowing in
                // Apply restrictions once the picker is dismissed.
                if !isShowing {
                    Task { await screenTimeService.applyRestrictions() }
                }
            }
            .fullScreenCover(isPresented: $showUnlockSession) {
                UnlockSessionView()
            }
        }
    }

    private func presentAppPicker() async {
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }
        showAppPicker = true
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Earn time.")
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Unlock freedom.")
                        .foregroundColor(DS.Colors.neon)
                }
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

                Text("Move your body.\nUnlock your time.")
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .layoutPriority(1)

            Spacer(minLength: DS.Spacing.sm)

            earnedRing
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var earnedRing: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(DS.Colors.border, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        DS.Gradients.neonRing,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Animation.standard, value: ringProgress)

                VStack(spacing: 0) {
                    Text("\(Int(todayEarnedMinutes))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("min")
                        .font(.caption2)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .frame(width: 92, height: 92)

            Text("earned today")
                .font(.caption2)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    // MARK: - Chips

    private var chipsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            StatCard(
                title: "day streak",
                value: "\(streak)",
                icon: "flame.fill",
                color: DS.Colors.accent
            )
            Button {
                Task { await presentAppPicker() }
            } label: {
                // Continuously pulsing neon glow + border so this chip reads
                // as the interactive one (tap to pick which apps to lock).
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = (sin(t * 2.2) + 1) / 2 // 0...1 breathing curve
                    StatCard(
                        title: "apps protected",
                        value: "\(lockedItemCount)",
                        icon: "shield.lefthalf.filled",
                        color: DS.Colors.neon
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Corner.medium, style: .continuous)
                            .stroke(DS.Colors.neon, lineWidth: 1.5)
                            .opacity(0.35 + phase * 0.65)
                    )
                    .scaleEffect(1 + phase * 0.025)
                    .shadow(color: DS.Colors.neon.opacity(0.25 + phase * 0.4), radius: 6 + phase * 10)
                }
            }
            .buttonStyle(.plain)
            StatCard(
                title: "Level \(levelNumber)",
                value: "\(totalXP)",
                icon: "star.fill",
                color: DS.Colors.secondary
            )
        }
    }

    // MARK: - Unlock button

    private var unlockButton: some View {
        Button {
            showUnlockSession = true
        } label: {
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.title3)
                Text("Unlock Screen Time")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .background(DS.Gradients.primaryButton)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Corner.large, style: .continuous))
            .shadow(color: DS.Colors.primary.opacity(0.35), radius: 14, y: 5)
        }
    }

    // MARK: - Recent sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(Strings.Dashboard.recentSessions)
                    .font(.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                if !recentSessions.isEmpty {
                    Text("See all")
                        .font(.subheadline)
                        .foregroundColor(DS.Colors.neon)
                }
            }

            if recentSessions.isEmpty {
                Text("No sessions yet. Start exercising!")
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xl)
            } else {
                ForEach(recentSessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack {
            if let exercise = session.exerciseType {
                ExerciseIconView(exerciseType: exercise, size: 22, color: DS.Colors.neon)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DS.Colors.textPrimary)
                    // TimelineView re-evaluates every 30s so "5s ago" ticks
                    // to "1 min ago" etc. without reopening the screen.
                    TimelineView(.periodic(from: .now, by: 30)) { _ in
                        Text(TimeFormatter.relativeDate(session.startedAt))
                            .font(.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.repCount) reps")
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textPrimary)
                Text(TimeFormatter.formatMinutes(session.earnedMinutes))
                    .font(.caption)
                    .foregroundColor(DS.Colors.accent)
            }
        }
        .padding(DS.Spacing.md)
        .dsCard(cornerRadius: DS.Corner.medium)
    }
}
