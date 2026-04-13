import SwiftUI
import SwiftData

// TEMP (screenshot capture): reset onboarding exactly once per cold launch
// so the flow can be re-screenshotted. Remove once captures are done.
private enum ScreenshotCaptureState {
    static var didResetOnboardingThisLaunch = false
}

struct RootView: View {
    @Query private var settings: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var screenTimeService: ScreenTimeService
    @StateObject private var purchases = PurchasesService.shared
    @State private var deepLinkUnlock: Bool = false

    private var userSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        Group {
            if userSettings?.hasCompletedOnboarding != true {
                OnboardingView()
            } else if !purchases.isSubscribed {
                PaywallView(dismissable: false)
            } else {
                MainTabView(showUnlock: $deepLinkUnlock)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fitscrollOpenUnlock)) { _ in
            deepLinkUnlock = true
        }
        .task {
            // TEMP (screenshot capture): force onboarding on each fresh
            // launch, but only once — so the user can still progress past
            // it when Start Using FitScroll is tapped.
            if !ScreenshotCaptureState.didResetOnboardingThisLaunch {
                ScreenshotCaptureState.didResetOnboardingThisLaunch = true
                if let existing = userSettings, existing.hasCompletedOnboarding {
                    existing.hasCompletedOnboarding = false
                    try? modelContext.save()
                }
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected format: fitscroll://unlock
        guard url.scheme == "fitscroll" else { return }
        if url.host == "unlock" {
            deepLinkUnlock = true
        }
    }
}

struct MainTabView: View {
    @Binding var showUnlock: Bool

    var body: some View {
        TabView {
            DashboardView(showUnlockSession: $showUnlock)
                .tabItem {
                    Label(Strings.Dashboard.title, systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label(Strings.History.title, systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label(Strings.Settings.title, systemImage: "gearshape.fill")
                }
        }
    }
}
