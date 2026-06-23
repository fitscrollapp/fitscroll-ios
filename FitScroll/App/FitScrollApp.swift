import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics

/// Minimal UIKit app delegate that exists solely to initialize Firebase at
/// the earliest possible lifecycle point. SwiftUI's `App` protocol doesn't
/// expose `application(_:didFinishLaunchingWithOptions:)`, which Firebase
/// recommends as the configuration site.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        // Enable Firebase Analytics DebugView: events stream to the Firebase
        // Console DebugView tab within seconds instead of waiting for the
        // hourly batch upload. Only affects Debug builds.
        UserDefaults.standard.set(true, forKey: "FIRAnalyticsDebugEnabled")
        UserDefaults.standard.set(-1, forKey: "FIRDebugEnabled")
        #endif

        FirebaseApp.configure()

        // Configure RevenueCat after Firebase so Crashlytics can capture
        // any init errors from the purchases SDK too.
        PurchasesService.shared.configure()

        // Install the local-notification delegate so taps on scheduled
        // unlock notifications route through our NotificationManager.
        NotificationManager.shared.bootstrap()

        // Fire a sentinel event so the Firebase project lights up on first
        // launch — useful for verifying the integration end-to-end.
        Analytics.logEvent("app_launched", parameters: [
            "launch_at": Date().timeIntervalSince1970
        ])

        return true
    }
}

@main
struct FitScrollApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var screenTimeService = ScreenTimeService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            UnlockCredit.self,
            ExerciseRewardRule.self,
            UsageLimitRule.self,
            UserSettings.self,
            UserJourneyProgress.self,
            EarnedBadge.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(screenTimeService)
        }
        .modelContainer(sharedModelContainer)
    }
}
