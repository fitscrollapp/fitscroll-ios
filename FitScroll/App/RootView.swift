import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var settings: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @StateObject private var purchases = PurchasesService.shared
    @State private var deepLinkUnlock: Bool = false
    @State private var challengeInvite: ChallengeInvite?
    /// Animated launch splash — covers the UI for the first ~1.6s.
    @State private var showSplash = true
    /// Lapsed subscriber tapped "see all plans" on the win-back screen —
    /// fall back to the regular paywall for the rest of this launch.
    @State private var winBackDeclined = false

    private var userSettings: UserSettings? {
        settings.first
    }

    /// DEBUG-only: when launched with `-uitesting` (Maestro/UI tests), skip
    /// onboarding + the paywall so gated main-tab screens are reachable.
    /// Compiled out of Release/TestFlight builds entirely.
    private var uiTestBypass: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains {
            $0.localizedCaseInsensitiveContains("uitesting")
                || $0.localizedCaseInsensitiveContains("demodata")
        }
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            Group {
                if !uiTestBypass && userSettings?.hasCompletedOnboarding != true {
                    OnboardingView()
                } else if !uiTestBypass && !purchases.isSubscribed {
                    // Returning lapsed subscribers get the one-tap win-back
                    // offer (iOS 18+, App Store eligibility permitting)
                    // instead of the full-price paywall.
                    if !winBackDeclined, let winBack = purchases.winBack {
                        WinBackView(package: winBack.package, offer: winBack.offer) {
                            winBackDeclined = true
                        }
                    } else {
                        PaywallView(dismissable: false)
                    }
                } else {
                    MainTabView(showUnlock: $deepLinkUnlock)
                }
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .zIndex(10)
                .transition(.opacity)
                // Purely decorative — never swallow early taps (they'd
                // silently no-op while the splash fades out).
                .allowsHitTesting(false)
            }
        }
        .tint(DS.Colors.neon)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            #if DEBUG
            DemoDataSeeder.seedIfRequested(context: modelContext)
            #endif
        }
        // Win-back eligibility depends on both customer info and offerings,
        // which arrive asynchronously after launch — re-check as they land.
        .onReceive(purchases.$customerInfo) { _ in
            Task { await purchases.refreshWinBackOffers() }
        }
        // The user may flip notification permission in iOS Settings while
        // we're backgrounded — re-report to the backend when it changed.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await NotificationManager.shared.syncPushAuthorizationIfChanged() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fitscrollOpenUnlock)) { _ in
            deepLinkUnlock = true
        }
        // Tapped FCM challenge push → resolve the code and open the invite.
        .onReceive(NotificationCenter.default.publisher(for: .fitscrollOpenChallenge)) { note in
            guard let code = note.object as? String else { return }
            Task { @MainActor in
                if let c = try? await FitScrollAPI.shared.challenge(id: code),
                   let exercise = ExerciseType(rawValue: c.exercise) {
                    presentChallenge(code: code, from: c.fromUsername, exercise: exercise, target: c.targetReps)
                }
            }
        }
        .fullScreenCover(item: $challengeInvite) { invite in
            ChallengeInviteView(invite: invite)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected formats:
        //   https://fit-scroll.app/c/<code>          (Universal Link)
        //   fitscroll://unlock
        //   fitscroll://challenge?id=<code>&ex=<raw>&target=<n>&from=<name>
        // `id`/`<code>` resolves the challenge from the backend; the inline
        // params are the offline fallback.
        if url.scheme == "https", url.host == "fit-scroll.app" {
            let parts = url.pathComponents // ["/", "c", "<code>"]
            if parts.count >= 3, parts[1] == "c" {
                let code = parts[2].uppercased()
                Task { @MainActor in
                    if let c = try? await FitScrollAPI.shared.challenge(id: code),
                       let exercise = ExerciseType(rawValue: c.exercise) {
                        presentChallenge(code: code, from: c.fromUsername, exercise: exercise, target: c.targetReps)
                    }
                }
            }
            return
        }
        guard url.scheme == "fitscroll" else { return }
        switch url.host {
        case "unlock":
            deepLinkUnlock = true
        case "challenge":
            let fallback = ChallengeInvite(url: url)
            if let code = ChallengeInvite.backendID(in: url) {
                Task { @MainActor in
                    if let c = try? await FitScrollAPI.shared.challenge(id: code),
                       let exercise = ExerciseType(rawValue: c.exercise) {
                        presentChallenge(code: code, from: c.fromUsername, exercise: exercise, target: c.targetReps)
                    } else if let fallback {
                        presentChallenge(code: code, from: fallback.from, exercise: fallback.exercise, target: fallback.target)
                    }
                }
            } else if let fallback {
                presentChallenge(code: nil, from: fallback.from, exercise: fallback.exercise, target: fallback.target)
            }
        default:
            break
        }
    }

    /// Register the incoming challenge in the notification inbox (dedup by
    /// backend code → accept-once) and open the invite screen.
    private func presentChallenge(code: String?, from: String, exercise: ExerciseType, target: Int) {
        let item = ChallengeInbox.shared.add(code: code, from: from, exercise: exercise, target: target)
        challengeInvite = ChallengeInvite(
            from: item.from,
            exercise: exercise,
            target: item.target,
            inboxID: item.id
        )
    }
}

struct MainTabView: View {
    @Binding var showUnlock: Bool
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(showUnlockSession: $showUnlock)
                .tabItem {
                    Label(Strings.Dashboard.title, systemImage: "house.fill")
                }
                .tag(0)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label(Strings.History.title, systemImage: "clock.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(Strings.Settings.title, systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { _, _ in
            SoundManager.click()
        }
        // Users who picked a username before the permission ask existed
        // (pre-build-34) never saw the prompt — ask once at startup so
        // challenge pushes can actually display.
        .task {
            if FitScrollAPI.shared.username != nil {
                await NotificationManager.shared.requestAuthorizationIfNeeded()
            }
        }
    }
}
