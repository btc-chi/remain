import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen someone sees when they open a resting app.
/// Note: a shield button cannot launch the app directly. The primary action closes the shield;
/// the app's morning notification is the path back into Rootwork.
final class GateShield: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    private func make(name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.48, green: 0.18, blue: 0.32, alpha: 0.12),
            icon: UIImage(systemName: "leaf"),
            title: .init(text: "Abide first.", color: .label),
            subtitle: .init(text: "\(name ?? "This app") is resting until your Rootwork is done.\n\n“Remain in me, and I in you.” John 15:4",
                            color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Close", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.48, green: 0.18, blue: 0.32, alpha: 1))
    }
}
