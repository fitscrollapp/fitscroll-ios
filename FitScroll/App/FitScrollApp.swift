import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseMessaging
import UserNotifications

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

        // Configure + start AppsFlyer (attribution). Starting here in
        // didFinishLaunching (not applicationDidBecomeActive, which SwiftUI
        // doesn't reliably call) guarantees the SDK reports the install.
        AppsFlyerService.shared.configure()
        // Bridge the AppsFlyer id into RevenueCat so subscription revenue
        // events flow to AppsFlyer → TikTok for the same install.
        PurchasesService.shared.setAppsflyerID(AppsFlyerService.shared.appsFlyerUID)

        // Install the local-notification delegate so taps on scheduled
        // unlock notifications route through our NotificationManager.
        NotificationManager.shared.bootstrap()

        // Pre-warm the sound engine off-main: loading the ~19 bundled effects
        // takes long enough to visibly delay the splash impact if it happens
        // lazily at first play.
        DispatchQueue.global(qos: .userInitiated).async {
            _ = SoundManager.shared
        }

        // Firebase Cloud Messaging — challenge pushes ("X challenged you",
        // "Y accepted your challenge"). APNs registration is cheap; the
        // user-facing permission prompt is asked contextually elsewhere.
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        // Fire a sentinel event so the Firebase project lights up on first
        // launch — useful for verifying the integration end-to-end.
        Analytics.logEvent("app_launched", parameters: [
            "launch_at": Date().timeIntervalSince1970
        ])

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.log("APNs registration failed: \(error.localizedDescription)", level: .warning)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        // Ship the token to the backend so challenge pushes reach this device.
        Task.detached {
            await FitScrollAPI.shared.setFCMToken(fcmToken)
        }
    }
}

@main
struct FitScrollApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
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
                .onChange(of: scenePhase) { _, phase in
                    // Request ATT once the scene is active (reliable in
                    // SwiftUI). AppsFlyer already started in didFinishLaunching.
                    if phase == .active {
                        AppsFlyerService.shared.requestTracking()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
