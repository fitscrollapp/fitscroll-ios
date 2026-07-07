import Foundation
import AppsFlyerLib
import AppTrackingTransparency

/// Central wrapper around the AppsFlyer SDK — mobile install attribution so
/// TikTok (and other) install campaigns can measure installs & events.
///
/// Flow: `configure()` runs at launch (sets keys, defers the first session
/// until the ATT prompt resolves). `requestTrackingAndStart()` runs when the
/// app becomes active — it shows the ATT prompt once, then starts the SDK.
final class AppsFlyerService: NSObject {
    static let shared = AppsFlyerService()

    /// AppsFlyer Dev Key (client-side, embedded in the app binary — same key
    /// for iOS & Android). From AppsFlyer → App Settings → Dev Key.
    private static let devKey = "6MNRhxaonR69hy72cnfJhP"

    /// Apple App Store id for this app (App Store Connect).
    private static let appleAppID = "6762100402"

    private var didStart = false

    /// Configure AND start at launch (from `didFinishLaunching`, which — unlike
    /// `applicationDidBecomeActive` — reliably fires in SwiftUI apps). The SDK
    /// holds the first report until ATT resolves or the 60s timeout elapses, so
    /// data still flows even if the ATT prompt is never answered.
    func configure() {
        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = Self.devKey
        af.appleAppID = Self.appleAppID
        af.delegate = self
        #if DEBUG
        af.isDebug = true
        #endif
        af.waitForATTUserAuthorization(timeoutInterval: 60)
        af.start()
        didStart = true
    }

    /// Request App Tracking Transparency. Call from the SwiftUI scene once it
    /// becomes active (the AppDelegate's `applicationDidBecomeActive` is not
    /// reliably called in SwiftUI). System shows the prompt only once; the SDK
    /// picks up the IDFA if granted, otherwise proceeds without it.
    func requestTracking() {
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }

    /// Unique AppsFlyer id for this install — bridged into RevenueCat so
    /// subscription events map back to the same AppsFlyer user.
    var appsFlyerUID: String { AppsFlyerLib.shared().getAppsFlyerUID() }

    /// Log an in-app event to AppsFlyer (forwarded to TikTok via the
    /// dashboard postback mappings).
    func logEvent(_ name: String, _ values: [String: Any] = [:]) {
        AppsFlyerLib.shared().logEvent(name, withValues: values.isEmpty ? nil : values)
    }
}

extension AppsFlyerService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        Logger.log("AppsFlyer conversion data received", level: .info)
    }

    func onConversionDataFail(_ error: Error) {
        Logger.log("AppsFlyer conversion data failed: \(error.localizedDescription)", level: .error)
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {}

    func onAppOpenAttributionFailure(_ error: Error) {}
}
