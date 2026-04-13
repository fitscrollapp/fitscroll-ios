import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var credits: [UnlockCredit]
    @Query private var limits: [UsageLimitRule]
    @State private var showAppSelection = false
    @Binding var showUnlockSession: Bool
    @State private var showPermissions = false

    init(showUnlockSession: Binding<Bool> = .constant(false)) {
        self._showUnlockSession = showUnlockSession
    }

    private var todayEarnedMinutes: Double {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDateInToday($0.startedAt) && $0.statusRaw == SessionStatus.completed.rawValue }
            .reduce(0) { $0 + $1.earnedMinutes }
    }

    private var recentSessions: [WorkoutSession] {
        Array(sessions.prefix(5))
    }

    private var hasActiveRestrictions: Bool {
        !screenTimeService.selectedApps.applicationTokens.isEmpty ||
        !screenTimeService.selectedApps.categoryTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if hasActiveRestrictions {
                        lockedAppsBanner
                    }
                    statusSection
                    statsSection
                    unlockButton
                    recentSessionsSection
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle(Strings.Dashboard.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAppSelection = true
                    } label: {
                        Image(systemName: "apps.iphone")
                    }
                }
            }
            .sheet(isPresented: $showAppSelection) {
                AppSelectionView()
            }
            .fullScreenCover(isPresented: $showUnlockSession) {
                UnlockSessionView()
            }
        }
    }

    private var lockedAppsBanner: some View {
        Button {
            showUnlockSession = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apps Locked")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Exercise now to earn screen time")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(DS.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.30, blue: 0.25),
                        Color(red: 0.90, green: 0.45, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(DS.Corner.large)
            .shadow(color: Color.red.opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var statusSection: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(screenTimeService.accessState.displayName)
                    .font(.headline)
                    .foregroundColor(statusColor)
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
    }

    private var statusColor: Color {
        switch screenTimeService.accessState {
        case .unrestricted: return DS.Colors.success
        case .restricted: return DS.Colors.error
        case .temporarilyUnlocked: return DS.Colors.warning
        }
    }

    private var statusMessage: String {
        switch screenTimeService.accessState {
        case .unrestricted: return "All apps are accessible"
        case .restricted: return "Selected apps are locked"
        case .temporarilyUnlocked: return "Apps temporarily unlocked"
        }
    }

    private var statsSection: some View {
        HStack(spacing: DS.Spacing.md) {
            StatCard(
                title: Strings.Dashboard.todayEarned,
                value: TimeFormatter.formatMinutes(todayEarnedMinutes),
                icon: "flame.fill",
                color: DS.Colors.accent
            )
            StatCard(
                title: Strings.Dashboard.activeLimits,
                value: "\(limits.filter(\.isEnabled).count)",
                icon: "lock.fill",
                color: DS.Colors.primary
            )
        }
    }

    private var unlockButton: some View {
        Button {
            showUnlockSession = true
        } label: {
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.title3)
                Text(Strings.Dashboard.unlockNow)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [DS.Colors.primary, DS.Colors.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(DS.Corner.large)
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(Strings.Dashboard.recentSessions)
                .font(.headline)

            if recentSessions.isEmpty {
                Text("No sessions yet. Start exercising!")
                    .foregroundColor(.secondary)
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
                ExerciseIconView(exerciseType: exercise, size: 22, color: DS.Colors.primary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(TimeFormatter.relativeDate(session.startedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.repCount) reps")
                    .font(.subheadline)
                Text(TimeFormatter.formatMinutes(session.earnedMinutes))
                    .font(.caption)
                    .foregroundColor(DS.Colors.accent)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.cardBackground)
        .cornerRadius(DS.Corner.medium)
    }
}
