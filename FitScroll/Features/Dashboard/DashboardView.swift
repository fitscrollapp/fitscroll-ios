import SwiftUI
import SwiftData
import FamilyControls

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var credits: [UnlockCredit]
    @Query private var journeyRecords: [UserJourneyProgress]
    @Binding var showUnlockSession: Bool
    @State private var showAppPicker = false
    @State private var showInbox = false
    @State private var inboxInvite: ChallengeInvite?

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
        #if DEBUG
        // Screenshot demo mode: pretend three apps are protected.
        if DemoDataSeeder.isRequested { return 3 }
        #endif
        return screenTimeService.selectedApps.applicationTokens.count +
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
                    pageHeader
                    heroSection
                    chipsRow
                    lockedAppsStrip
                    unlockButton
                    recentSessionsSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
            .onChange(of: ringProgress) { old, new in
                // Daily goal ring hits 100% → celebratory bonus chime.
                if old < 1, new >= 1 {
                    SoundManager.goalRing()
                    HapticManager.sessionCompleted()
                }
            }
            // Pull directed challenges into the bell on open (covers pushes
            // missed while the app was closed / permission denied).
            .task { await syncInbox() }
            // ...and every time the app returns to the foreground, so a
            // challenge sent while backgrounded shows up without a restart.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await syncInbox() }
                }
            }
            // Foreground FCM push → immediate bell refresh.
            .onReceive(NotificationCenter.default.publisher(for: .fitscrollInboxRefresh)) { _ in
                Task { await syncInbox() }
            }
            .fullScreenCover(isPresented: $showUnlockSession) {
                UnlockSessionView()
            }
            // Notification center (bell): received + sent challenges.
            .sheet(isPresented: $showInbox) {
                ChallengeInboxView { invite in
                    showInbox = false
                    inboxInvite = invite
                }
            }
            .fullScreenCover(item: $inboxInvite) { invite in
                ChallengeInviteView(invite: invite)
            }
        }
    }

    private func syncInbox() async {
        guard FitScrollAPI.shared.username != nil else { return }
        if let mine = try? await FitScrollAPI.shared.myChallenges() {
            ChallengeInbox.shared.syncRemote(received: mine.received)
        }
    }

    private func presentAppPicker() async {
        if AuthorizationCenter.shared.authorizationStatus != .approved {
            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        }
        showAppPicker = true
    }

    // MARK: - Page header

    /// Leaderboard-style page header: big black rounded title on the left,
    /// a streak pill on the right — same visual language on every tab.
    private var pageHeader: some View {
        HStack(alignment: .center) {
            Text(Strings.Dashboard.title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("\(streak)")
                    .font(.caption2).fontWeight(.bold)
                    .monospacedDigit()
            }
            .foregroundColor(DS.Colors.accent)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(DS.Colors.accent.opacity(0.15)))
            .overlay(Capsule().stroke(DS.Colors.accent.opacity(0.4), lineWidth: 1))

            ChallengeBellButton { showInbox = true }
                .padding(.leading, DS.Spacing.sm)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Strings.Dashboard.heroEarnTime)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(Strings.Dashboard.heroUnlockFreedom)
                        .foregroundColor(DS.Colors.neon)
                }
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

                Text(Strings.Dashboard.heroSubtitle)
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
                    Text(Strings.Dashboard.ringMinutesUnit)
                        .font(.caption2)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .frame(width: 92, height: 92)

            Text(Strings.Dashboard.ringEarnedToday)
                .font(.caption2)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    // MARK: - Chips

    private var chipsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            DuoStatTile(
                value: "\(streak)",
                title: Strings.Dashboard.chipDayStreak,
                systemName: "flame.fill",
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
                    DuoStatTile(
                        value: "\(lockedItemCount)",
                        title: Strings.Dashboard.chipAppsProtected,
                        systemName: "shield.lefthalf.filled",
                        color: DS.Colors.neon
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Corner.xl, style: .continuous)
                            .stroke(DS.Colors.neon, lineWidth: 2)
                            .opacity(0.35 + phase * 0.65)
                    )
                    .scaleEffect(1 + phase * 0.025)
                    .shadow(color: DS.Colors.neon.opacity(0.25 + phase * 0.4), radius: 6 + phase * 10)
                }
            }
            .buttonStyle(.plain)
            DuoStatTile(
                value: "\(totalXP)",
                title: String(format: Strings.Dashboard.chipLevelFormat, levelNumber),
                systemName: "star.fill",
                color: DS.Colors.secondary
            )
        }
    }

    // MARK: - Locked apps strip

    /// Single horizontally-scrolling row of the shielded apps' icons, right
    /// under the stat chips. Each token is rendered by the SYSTEM via
    /// `Label(token)` — the app itself never learns which apps they are
    /// (FamilyControls privacy model). The full list is managed by tapping
    /// the "apps protected" chip, which opens the system picker.
    @ViewBuilder
    private var lockedAppsStrip: some View {
        #if DEBUG
        if DemoDataSeeder.isRequested {
            demoLockedStrip
        } else {
            realLockedStrip
        }
        #else
        realLockedStrip
        #endif
    }

    #if DEBUG
    /// Screenshot demo mode: FamilyControls tokens can't be faked, so render
    /// three lookalike tiles (photo-app / X / music-app) purely for captures.
    private var demoLockedStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                lockedTile {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.98, green: 0.75, blue: 0.24),
                                        Color(red: 0.91, green: 0.26, blue: 0.43),
                                        Color(red: 0.55, green: 0.23, blue: 0.86),
                                    ],
                                    startPoint: .bottomLeading, endPoint: .topTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                        Image(systemName: "camera")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                lockedTile {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 34, height: 34)
                        Text("𝕏")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                lockedTile {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 34, height: 34)
                        Image(systemName: "music.note")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 0.92))
                            .shadow(color: Color(red: 1.0, green: 0.17, blue: 0.33), radius: 0, x: 1.6, y: 1.2)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
    #endif

    @ViewBuilder
    private var realLockedStrip: some View {
        let apps = Array(screenTimeService.selectedApps.applicationTokens)
        let categories = Array(screenTimeService.selectedApps.categoryTokens)
        if !apps.isEmpty || !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(apps, id: \.self) { token in
                        lockedTile { Label(token).labelStyle(.iconOnly).scaleEffect(1.8) }
                    }
                    ForEach(categories, id: \.self) { token in
                        lockedTile { Label(token).labelStyle(.iconOnly).scaleEffect(1.8) }
                    }
                }
                .padding(.top, 6) // room for the lock badge overhang
            }
        }
    }

    /// Rounded tile + a mini orange padlock pinned to the top-right corner so
    /// each app in the strip unmistakably reads as "locked".
    @ViewBuilder
    private func lockedTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 46, height: 46)
            .background(DS.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle().fill(DS.Colors.accent)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(DS.Colors.background, lineWidth: 2))
                .offset(x: 5, y: -5)
            }
    }

    // MARK: - Unlock button

    private var unlockButton: some View {
        DuoButton(fill: DS.Colors.primary, foreground: .white, height: 62) {
            showUnlockSession = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "lock.open.fill")
                Text(Strings.Dashboard.unlockScreenTime)
                Image(systemName: "arrow.right")
            }
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
                    Text(Strings.Dashboard.seeAll)
                        .font(.subheadline)
                        .foregroundColor(DS.Colors.neon)
                }
            }

            if recentSessions.isEmpty {
                Text(Strings.Dashboard.noSessionsYet)
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
        HStack(spacing: DS.Spacing.md) {
            if let exercise = session.exerciseType {
                DuoIconBadge(systemName: exercise.iconName, color: Duo.color(for: exercise), size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
                Text(String(format: Strings.Dashboard.repsFormat, session.repCount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text(TimeFormatter.formatMinutes(session.earnedMinutes))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.accent)
            }
        }
        .padding(DS.Spacing.md)
        .dsCard(cornerRadius: DS.Corner.large)
    }
}
