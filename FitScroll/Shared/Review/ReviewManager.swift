import StoreKit
import SwiftUI

/// Centralizes App Store review prompting.
///
/// Apple throttles the system review dialog to ~3 prompts per 365 days and
/// never guarantees it actually appears, so we only ask at genuine positive
/// moments (a completed workout where reps were earned) and never more than
/// once per app version. Burning a yearly slot on a forgettable moment is
/// the main thing to avoid — hence the session-count + per-version gating.
enum ReviewManager {
    /// Numeric App Store id, used to build the manual "write a review" link.
    static let appStoreID = "6762100402"

    /// Deep link to the App Store review composer. Used by the manual
    /// "Rate FitScroll" row in Settings (a button must use this URL — the
    /// system `requestReview` prompt may legitimately decide to show nothing).
    static var writeReviewURL: URL {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    private static let sessionCountKey = "fitscroll.review.completedSessions"
    private static let lastPromptedVersionKey = "fitscroll.review.lastPromptedVersion"

    /// Don't ask until the user has felt the value a few times.
    private static let minSessionsBeforePrompt = 3

    private static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Record one genuinely successful workout (reps earned). Call this every
    /// time, regardless of whether we end up prompting — it feeds the gate.
    static func recordSuccessfulSession() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: sessionCountKey) + 1, forKey: sessionCountKey)
    }

    /// Trigger the system review prompt if the user has had enough good
    /// moments and hasn't already been asked on this app version.
    @MainActor
    static func requestReviewIfAppropriate(_ requestReview: RequestReviewAction) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: sessionCountKey) >= minSessionsBeforePrompt else { return }
        guard defaults.string(forKey: lastPromptedVersionKey) != currentAppVersion else { return }

        defaults.set(currentAppVersion, forKey: lastPromptedVersionKey)
        requestReview()
    }
}
