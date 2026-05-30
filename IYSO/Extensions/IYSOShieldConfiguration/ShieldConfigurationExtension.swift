import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private func iysoConfiguration() -> ShieldConfiguration {
        let accent = UIColor(red: 0.18, green: 0.55, blue: 1.0, alpha: 1)
        let subtitleColor = UIColor(white: 0.65, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.07, green: 0.06, blue: 0.06, alpha: 1),
            icon: nil,
            title: ShieldConfiguration.Label(
                text: "This app is NOT a camera",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Stay in the moment and keep shooting.",
                color: subtitleColor
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Take me back to IYSO",
                color: .white
            ),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        iysoConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        iysoConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        iysoConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        iysoConfiguration()
    }
}
