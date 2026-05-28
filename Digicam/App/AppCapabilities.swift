import Foundation

/// Toggle for local UI development vs. production builds with team provisioning.
///
/// Before merging to `main` for your teammate:
/// 1. Set `useProductionEntitlements` to `true`
/// 2. Copy `Digicam.entitlements.production` → `Digicam.entitlements`
enum AppCapabilities {
    /// `false` = personal-team signing (no NFC / Family Controls entitlements).
    /// `true` = full capabilities (requires org developer account + matching profile).
    static let useProductionEntitlements = false

    static var usesNFC: Bool { useProductionEntitlements }
    static var usesFamilyControls: Bool { useProductionEntitlements }
}
