import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    /// Loads the FitScroll logo bundled inside this extension's resources.
    /// Extensions don't share assets with the main app, so the PNG is
    /// included directly in the extension target.
    private var logoImage: UIImage? {
        guard let url = Bundle(for: ShieldConfigurationExtension.self)
            .url(forResource: "FitScrollLogo", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(red: 0.04, green: 0.07, blue: 0.18, alpha: 1.0),
            icon: logoImage,
            title: ShieldConfiguration.Label(
                text: "Time to Move 💪",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is locked.\nOpen FitScroll and finish an exercise\nto earn screen time.",
                color: UIColor(white: 1.0, alpha: 0.75)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0)
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }
}
