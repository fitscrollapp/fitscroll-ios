import ManagedSettings
import Foundation

/// Handles shield button taps.
///
/// iOS limits what a shield action extension can do — you can only respond
/// with `.close`, `.defer`, or `.none`. There is no supported API for
/// launching another app from within a shield action handler. The best we
/// can do is dismiss the shield on primary-tap; the main FitScroll app's
/// dashboard prominently prompts the user to start a workout once they
/// land back on the home screen.
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // "Close" button → dismiss the shield so the user can switch to
            // FitScroll from the home screen and start exercising.
            return .close
        case .secondaryButtonPressed:
            // Secondary button is not exposed by ShieldConfiguration, so this
            // branch should never fire in practice.
            return .none
        @unknown default:
            return .none
        }
    }
}
