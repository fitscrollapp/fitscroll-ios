import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications
import Foundation
import os

private let monitorLog = os.Logger(
    subsystem: "com.fitscroll",
    category: "screentime.extension"
)

/// Runs in its own process so shield re-application survives main-app
/// suspension. The main app sets up a DeviceActivity schedule with
/// usage-threshold events, and this class:
///  1. Posts a "1 minute left" notification when the warning event fires
///  2. Re-applies the shield and posts the "locked again" notification
///     when the expired event fires
/// Usage-based thresholds are the only way to get an arbitrarily short
/// unlock window — plain DeviceActivitySchedules have a 15-minute
/// minimum interval.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private static let appGroupID = "group.com.huseyinbabal.fitscroll"
    private static let selectedAppsKey = "fitscroll.selectedApps.v1"
    private static let unlockDurationKey = "fitscroll.unlock.duration"
    private static let unlockItemCountKey = "fitscroll.unlock.itemCount"
    /// Set by the main app when it's about to stopMonitoring as part of
    /// starting a new unlock window. iOS fires intervalDidEnd when a
    /// schedule is stopped, which would otherwise trip the safety-net
    /// reapply and re-shield the apps we just unlocked.
    private static let skipReapplyKey = "fitscroll.skipReapply"
    /// Mirrors ScreenTimeService.accessStateKey — the extension writes
    /// "restricted" here when it re-applies the shield so the dashboard
    /// shows the correct state after a cold launch.
    private static let accessStateKey = "fitscroll.accessState"

    private let store = ManagedSettingsStore(named: .fitscroll)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        monitorLog.notice(
            "intervalDidStart \(activity.rawValue, privacy: .public) at=\(Date().timeIntervalSince1970, privacy: .public)"
        )
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        monitorLog.notice(
            "intervalDidEnd \(activity.rawValue, privacy: .public) at=\(Date().timeIntervalSince1970, privacy: .public)"
        )
        guard activity == .unlockWindow else { return }

        // If the main app just called stopMonitoring to start a fresh
        // unlock window, it flips skipReapply so this safety-net path
        // doesn't immediately re-shield the apps it just unlocked.
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        if defaults?.bool(forKey: Self.skipReapplyKey) == true {
            monitorLog.notice("intervalDidEnd skipReapply flag set — clearing flag, not re-shielding")
            defaults?.set(false, forKey: Self.skipReapplyKey)
            return
        }

        // Safety net: if the usage-threshold event somehow didn't fire
        // (e.g. user never opened any of the shielded apps), still
        // re-lock at end-of-schedule so we don't leave them open.
        reapplyShield()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        monitorLog.notice(
            "eventDidReachThreshold event=\(event.rawValue, privacy: .public) activity=\(activity.rawValue, privacy: .public) at=\(Date().timeIntervalSince1970, privacy: .public)"
        )

        guard activity == .unlockWindow else { return }

        switch event {
        case .unlockWarning:
            postNotification(
                id: "fitscroll.unlock.warning",
                title: "1 minute left",
                body: unlockItemCount() > 1
                    ? "\(unlockItemCount()) unlocked apps lock in 60 seconds. Earn more time?"
                    : "Your unlocked app locks in 60 seconds. Earn more time?"
            )
        case .unlockExpired:
            reapplyShield()
            let count = unlockItemCount()
            postNotification(
                id: "fitscroll.unlock.expired",
                title: count > 1 ? "\(count) apps locked again" : "App locked again",
                body: "Tap to earn more screen time with a quick workout."
            )
        default:
            break
        }
    }

    // MARK: - Helpers

    private func reapplyShield() {
        guard let selection = loadSelection() else {
            monitorLog.error("reapplyShield: could not load selection")
            return
        }
        monitorLog.notice(
            "reapplyShield apps=\(selection.applicationTokens.count, privacy: .public) cats=\(selection.categoryTokens.count, privacy: .public)"
        )

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        } else {
            store.shield.applications = nil
        }

        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }

        // Mirror the state back so the main app's dashboard shows
        // "Selected apps are locked" after the next cold launch instead
        // of the stale "All apps accessible".
        UserDefaults(suiteName: Self.appGroupID)?
            .set("restricted", forKey: Self.accessStateKey)
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = defaults.data(forKey: Self.selectedAppsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private func unlockItemCount() -> Int {
        UserDefaults(suiteName: Self.appGroupID)?
            .integer(forKey: Self.unlockItemCountKey) ?? 0
    }

    private func postNotification(id: String, title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        // Inspect current auth + settings so we can tell from logs
        // whether banners are actually allowed. This runs async — the
        // actual request below goes out regardless so we don't miss
        // the window.
        center.getNotificationSettings { settings in
            monitorLog.notice(
                "notif settings auth=\(settings.authorizationStatus.rawValue, privacy: .public) alert=\(settings.alertSetting.rawValue, privacy: .public) banner=\(settings.alertStyle.rawValue, privacy: .public) notif=\(settings.notificationCenterSetting.rawValue, privacy: .public)"
            )
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["destination": "unlock"]
        content.threadIdentifier = "fitscroll.unlock"
        // Time-sensitive interruption level asks iOS to display the
        // banner even when the user is in Focus mode. Silently ignored
        // on iOS < 15 and if the app lacks the entitlement.
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                monitorLog.error(
                    "postNotification failed: \(error.localizedDescription, privacy: .public)"
                )
            } else {
                monitorLog.notice(
                    "postNotification added \(id, privacy: .public) at=\(Date().timeIntervalSince1970, privacy: .public)"
                )
            }
        }
    }
}

extension DeviceActivityName {
    static let unlockWindow = DeviceActivityName("com.fitscroll.unlockWindow")
}

extension DeviceActivityEvent.Name {
    static let unlockWarning = DeviceActivityEvent.Name("com.fitscroll.unlock.warning")
    static let unlockExpired = DeviceActivityEvent.Name("com.fitscroll.unlock.expired")
}

extension ManagedSettingsStore.Name {
    static let fitscroll = Self("fitscroll")
}
