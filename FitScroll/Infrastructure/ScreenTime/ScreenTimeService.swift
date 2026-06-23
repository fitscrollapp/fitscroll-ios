import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import os

private let screenTimeLog = os.Logger(
    subsystem: "com.fitscroll",
    category: "screentime"
)

protocol ScreenTimeServiceProtocol: Sendable {
    func requestAuthorization() async throws
    func selectApps() async throws
    func applyRestrictions() async
    func removeRestrictions() async
    func applyTemporaryUnlock(durationMinutes: Double) async
    var isAuthorized: Bool { get }
}

@MainActor
final class ScreenTimeService: ObservableObject, ScreenTimeServiceProtocol {
    static let shared = ScreenTimeService()

    @Published private(set) var isAuthorized: Bool = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection() {
        didSet { persistSelectedApps() }
    }
    @Published private(set) var accessState: AppAccessState = .unrestricted {
        didSet { persistAccessState() }
    }

    // Named store ensures iOS associates these settings with our app's
    // Shield Configuration extension. The default store sometimes fails to
    // trigger custom shields on newer iOS versions.
    private let store = ManagedSettingsStore(named: .fitscroll)
    private let center = DeviceActivityCenter()

    private static let appGroupID = "group.com.huseyinbabal.fitscroll"
    private static let selectedAppsDefaultsKey = "fitscroll.selectedApps.v1"
    private static let accessStateKey = "fitscroll.accessState"

    /// Shared UserDefaults backed by the app group so the
    /// DeviceActivityMonitor extension can read the current selection
    /// when the unlock window ends and re-apply the shield.
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    init() {
        // FamilyActivitySelection is Codable, so we persist the user's
        // restricted-app choice to UserDefaults and restore it at launch.
        // Without this, a cold start leaves the UI showing "0 apps" even
        // though the Managed Settings shield is still active.
        let group = UserDefaults(suiteName: Self.appGroupID)
        if let data = group?.data(forKey: Self.selectedAppsDefaultsKey)
            ?? UserDefaults.standard.data(forKey: Self.selectedAppsDefaultsKey),
           let decoded = try? JSONDecoder().decode(
            FamilyActivitySelection.self, from: data
           ) {
            self.selectedApps = decoded
        }

        // Restore the last-known shield state. The actual iOS-side shield
        // is persisted by ManagedSettings, but our in-memory accessState
        // isn't — so without this, every cold launch shows "All apps
        // accessible" even while the store is still shielding things.
        if let raw = group?.string(forKey: Self.accessStateKey),
           let state = AppAccessState(rawValue: raw) {
            self.accessState = state
        } else if !self.selectedApps.applicationTokens.isEmpty
                   || !self.selectedApps.categoryTokens.isEmpty {
            // First launch on a build that persists state, but the user
            // already has apps configured from a prior install: assume
            // the shield is active. It's the far more likely state than
            // .unrestricted when selectedApps is non-empty.
            self.accessState = .restricted
        }
    }

    private func persistSelectedApps() {
        guard let data = try? JSONEncoder().encode(selectedApps) else { return }
        // Write to both: the app group (for the extension) and
        // UserDefaults.standard (for backwards compat with earlier builds).
        sharedDefaults.set(data, forKey: Self.selectedAppsDefaultsKey)
        UserDefaults.standard.set(data, forKey: Self.selectedAppsDefaultsKey)
    }

    private func persistAccessState() {
        sharedDefaults.set(accessState.rawValue, forKey: Self.accessStateKey)
    }

    func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
            throw ScreenTimeError.authorizationDenied
        }
    }

    func selectApps() async throws {
        // FamilyActivityPicker is used in SwiftUI views directly
        // This method validates the selection
        guard !selectedApps.applicationTokens.isEmpty ||
              !selectedApps.categoryTokens.isEmpty else {
            throw ScreenTimeError.noAppsSelected
        }
    }

    func applyRestrictions() async {
        let applications = selectedApps.applicationTokens
        let categories = selectedApps.categoryTokens

        screenTimeLog.notice(
            "applyRestrictions apps=\(applications.count) categories=\(categories.count) at=\(Date().timeIntervalSince1970, privacy: .public)"
        )

        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)

        accessState = .restricted
    }

    func removeRestrictions() async {
        screenTimeLog.notice("removeRestrictions at=\(Date().timeIntervalSince1970, privacy: .public)")
        // Tell the DeviceActivityMonitor extension to skip its
        // intervalDidEnd re-apply safety net. Without this, calling
        // stopMonitoring below (inside scheduleUsageBasedUnlock) fires
        // intervalDidEnd, which re-shields the apps we just unlocked.
        sharedDefaults.set(true, forKey: "fitscroll.skipReapply")

        // Setting individual shield properties to nil on a named
        // ManagedSettingsStore doesn't reliably propagate — apps stay
        // shielded intermittently. clearAllSettings() atomically resets
        // every managed setting on the store, which does propagate.
        store.clearAllSettings()
        accessState = .unrestricted
    }

    func applyTemporaryUnlock(durationMinutes: Double) async {
        screenTimeLog.notice(
            "applyTemporaryUnlock duration=\(durationMinutes)min at=\(Date().timeIntervalSince1970, privacy: .public)"
        )

        // Make sure iOS has been asked for notification permission —
        // without this, the extension's re-lock notifications are
        // silently dropped. Auth grant is shared between main app and
        // the extension's notification center.
        await NotificationManager.shared.requestAuthorizationIfNeeded()

        await removeRestrictions()
        accessState = .temporarilyUnlocked

        // Save the unlock duration so the extension knows what message to
        // show in notifications when its usage-threshold events fire.
        let restrictedItemCount =
            selectedApps.applicationTokens.count + selectedApps.categoryTokens.count
        sharedDefaults.set(durationMinutes, forKey: "fitscroll.unlock.duration")
        sharedDefaults.set(restrictedItemCount, forKey: "fitscroll.unlock.itemCount")

        // Hand the re-lock off to the DeviceActivityMonitor extension via
        // USAGE-BASED DeviceActivityEvent thresholds. Unlike a plain
        // DeviceActivitySchedule (which has a 15-minute minimum duration),
        // event thresholds can be arbitrarily short. This also matches
        // user intuition: the timer only counts while the user is
        // actually using the shielded apps.
        scheduleUsageBasedUnlock(durationMinutes: durationMinutes)

        // Usage-based thresholds only fire while the user is actively in
        // the shielded apps. If they set a 5-min unlock but never open
        // Twitter, the extension notifications never arrive. Schedule a
        // wall-clock fallback countdown so the user always hears back
        // from FitScroll when the window closes.
        NotificationManager.shared.scheduleUnlockCountdown(
            durationMinutes: durationMinutes,
            restrictedItemCount: restrictedItemCount
        )
    }

    /// Starts a DeviceActivity schedule with two usage-threshold events:
    ///   - `.unlockWarning` at `durationMinutes - 1` minutes of usage
    ///   - `.unlockExpired` at `durationMinutes` minutes of usage
    /// The extension fires both notifications and re-applies the shield
    /// for `.unlockExpired`. The surrounding schedule just needs to be
    /// valid (≥15 min); we use end-of-day.
    private func scheduleUsageBasedUnlock(durationMinutes: Double) {
        center.stopMonitoring([.unlockWindow])

        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(
            bySettingHour: 23, minute: 59, second: 59, of: now
        ) ?? now.addingTimeInterval(12 * 3600)

        // If we're within 15 minutes of midnight, push the schedule end
        // into tomorrow so we clear the 15-minute minimum.
        let scheduleEnd: Date
        if endOfDay.timeIntervalSince(now) < 15 * 60 {
            scheduleEnd = now.addingTimeInterval(60 * 60)
        } else {
            scheduleEnd = endOfDay
        }

        let startComponents = calendar.dateComponents(
            [.hour, .minute, .second], from: now
        )
        let endComponents = calendar.dateComponents(
            [.hour, .minute, .second], from: scheduleEnd
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        let durationSeconds = max(60, Int(durationMinutes * 60))

        let expiredEvent = DeviceActivityEvent(
            applications: selectedApps.applicationTokens,
            categories: selectedApps.categoryTokens,
            threshold: DateComponents(second: durationSeconds)
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .unlockExpired: expiredEvent
        ]

        // Only attach a 1-minute warning event if we actually have more
        // than a minute of unlock time — otherwise the warning threshold
        // would be zero and iOS rejects it.
        if durationSeconds > 60 {
            let warningEvent = DeviceActivityEvent(
                applications: selectedApps.applicationTokens,
                categories: selectedApps.categoryTokens,
                threshold: DateComponents(second: durationSeconds - 60)
            )
            events[.unlockWarning] = warningEvent
        }

        screenTimeLog.notice(
            "scheduleUsageBasedUnlock duration=\(durationMinutes, privacy: .public)min thresholds=[expired:\(durationSeconds, privacy: .public)s warning:\(durationSeconds > 60 ? durationSeconds - 60 : -1, privacy: .public)s]"
        )

        do {
            try center.startMonitoring(
                .unlockWindow,
                during: schedule,
                events: events
            )
            screenTimeLog.notice("startMonitoring(.unlockWindow) OK (usage-based)")
        } catch {
            screenTimeLog.error(
                "startMonitoring(.unlockWindow) FAILED: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.unlockWindow])
    }
}

extension DeviceActivityName {
    /// Schedule whose usage-threshold events drive the unlock window.
    /// Declared in the main app AND the extension — both must use the
    /// same string or iOS won't route the callback correctly.
    static let unlockWindow = DeviceActivityName("com.fitscroll.unlockWindow")
}

extension DeviceActivityEvent.Name {
    /// Fires when the user has consumed `duration - 1 min` of usage on
    /// the shielded apps. Triggers the "1 minute left" notification.
    static let unlockWarning = DeviceActivityEvent.Name("com.fitscroll.unlock.warning")
    /// Fires when the user has consumed the full unlock duration. Triggers
    /// the "apps locked again" notification and re-applies the shield.
    static let unlockExpired = DeviceActivityEvent.Name("com.fitscroll.unlock.expired")
}

extension ManagedSettingsStore.Name {
    static let fitscroll = Self("fitscroll")
}

enum ScreenTimeError: LocalizedError {
    case authorizationDenied
    case noAppsSelected
    case restrictionFailed
    case monitoringFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied: return "Screen Time authorization was denied"
        case .noAppsSelected: return "No apps were selected for restriction"
        case .restrictionFailed: return "Failed to apply app restrictions"
        case .monitoringFailed: return "Failed to start usage monitoring"
        }
    }
}
