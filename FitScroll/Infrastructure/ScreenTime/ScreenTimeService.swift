import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

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
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published private(set) var accessState: AppAccessState = .unrestricted

    // Named store ensures iOS associates these settings with our app's
    // Shield Configuration extension. The default store sometimes fails to
    // trigger custom shields on newer iOS versions.
    private let store = ManagedSettingsStore(named: .fitscroll)
    private let center = DeviceActivityCenter()
    private var unlockTimer: Task<Void, Never>?

    nonisolated init() {}

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

        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)

        accessState = .restricted
    }

    func removeRestrictions() async {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        accessState = .unrestricted
    }

    func applyTemporaryUnlock(durationMinutes: Double) async {
        await removeRestrictions()
        accessState = .temporarilyUnlocked

        // Schedule the 1-minute warning + end-of-unlock notifications so the
        // user knows when the restrictions are about to kick back in. Apple's
        // FamilyControls tokens are opaque so we can't include app names —
        // we pass the selection count and the message is built around that.
        let restrictedCount =
            selectedApps.applicationTokens.count +
            selectedApps.categoryTokens.count
        NotificationManager.shared.scheduleUnlockCountdown(
            durationMinutes: durationMinutes,
            restrictedItemCount: restrictedCount
        )

        unlockTimer?.cancel()
        unlockTimer = Task {
            let nanoseconds = UInt64(durationMinutes * 60 * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)

            if !Task.isCancelled {
                await self.applyRestrictions()
            }
        }
    }

    func scheduleDeviceActivityMonitoring(limitMinutes: Int) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: selectedApps.applicationTokens,
            categories: selectedApps.categoryTokens,
            threshold: DateComponents(minute: limitMinutes)
        )

        do {
            try center.startMonitoring(
                .daily,
                during: schedule,
                events: [.threshold: event]
            )
        } catch {
            Logger.log("Failed to start monitoring: \(error)", level: .error)
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("com.fitscroll.daily")
}

extension DeviceActivityEvent.Name {
    static let threshold = DeviceActivityEvent.Name("com.fitscroll.threshold")
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
