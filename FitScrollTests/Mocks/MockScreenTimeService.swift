import Foundation
@testable import FitScroll

final class MockScreenTimeService: ScreenTimeServiceProtocol, @unchecked Sendable {
    var isAuthorized: Bool = false
    var restrictionsApplied: Bool = false
    var temporaryUnlockDuration: Double?
    var authorizationError: Error?

    func requestAuthorization() async throws {
        if let error = authorizationError {
            throw error
        }
        isAuthorized = true
    }

    func selectApps() async throws {
        // No-op in mock
    }

    func applyRestrictions() async {
        restrictionsApplied = true
    }

    func removeRestrictions() async {
        restrictionsApplied = false
    }

    func applyTemporaryUnlock(durationMinutes: Double) async {
        restrictionsApplied = false
        temporaryUnlockDuration = durationMinutes
    }
}
