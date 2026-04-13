import Foundation
import UserNotifications
import UIKit

extension Notification.Name {
    static let fitscrollOpenUnlock = Notification.Name("fitscroll.openUnlock")
}

/// Handles local notifications for the temporary unlock countdown:
/// 1. "1 minute left" — fires 60s before the unlock expires
/// 2. "Locked again" — fires when the unlock window closes
/// Tapping either routes the user into the unlock session flow.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private enum Identifier {
        static let warning = "fitscroll.unlock.warning"
        static let expired = "fitscroll.unlock.expired"
    }

    private enum UserInfoKey {
        static let destination = "destination"
    }

    private enum Destination {
        static let unlock = "unlock"
    }

    override init() {
        super.init()
        center.delegate = self
    }

    func bootstrap() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        default:
            break
        }
    }

    /// Schedules the 1-minute warning and the "locked again" notification
    /// for a temporary unlock of `durationMinutes` starting now.
    /// `restrictedItemCount` is the total of selected apps + categories so
    /// the body text can mention how many things are about to re-lock.
    /// Apple's FamilyControls tokens are intentionally opaque, so we cannot
    /// reference apps by name — count is the most specific signal we have.
    func scheduleUnlockCountdown(durationMinutes: Double, restrictedItemCount: Int) {
        cancelUnlockCountdown()

        Task {
            await requestAuthorizationIfNeeded()

            let warningTitle = Strings.Notifications.oneMinuteWarningTitle
            let warningBody: String
            if restrictedItemCount <= 1 {
                warningBody = Strings.Notifications.oneMinuteWarningBodySingular
            } else {
                warningBody = String(
                    format: Strings.Notifications.oneMinuteWarningBodyPluralFormat,
                    restrictedItemCount
                )
            }

            let lockedTitle: String
            let lockedBody: String
            if restrictedItemCount <= 1 {
                lockedTitle = Strings.Notifications.lockedAgainTitleSingular
                lockedBody = Strings.Notifications.lockedAgainBodySingular
            } else {
                lockedTitle = String(
                    format: Strings.Notifications.lockedAgainTitlePluralFormat,
                    restrictedItemCount
                )
                lockedBody = String(
                    format: Strings.Notifications.lockedAgainBodyPluralFormat,
                    restrictedItemCount
                )
            }

            let totalSeconds = durationMinutes * 60
            // Only schedule the warning if we actually have >1 minute of
            // unlock time — otherwise the warning would fire in the past.
            if totalSeconds > 60 {
                let warningSeconds = totalSeconds - 60
                scheduleNotification(
                    id: Identifier.warning,
                    title: warningTitle,
                    body: warningBody,
                    after: warningSeconds
                )
            }

            scheduleNotification(
                id: Identifier.expired,
                title: lockedTitle,
                body: lockedBody,
                after: totalSeconds
            )
        }
    }

    func cancelUnlockCountdown() {
        center.removePendingNotificationRequests(withIdentifiers: [
            Identifier.warning,
            Identifier.expired,
        ])
    }

    private func scheduleNotification(
        id: String,
        title: String,
        body: String,
        after seconds: TimeInterval
    ) {
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [UserInfoKey.destination: Destination.unlock]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                Logger.log("Failed to schedule \(id): \(error)", level: .error)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner + play sound even if the app is in the foreground.
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let dest = response.notification.request.content.userInfo[UserInfoKey.destination] as? String
        if dest == Destination.unlock {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .fitscrollOpenUnlock, object: nil)
            }
        }
        completionHandler()
    }
}
