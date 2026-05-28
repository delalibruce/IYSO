import Foundation

/// Feature flags for entitlement-gated capabilities.
///
/// - **Debug:** UI-only path (Personal Team can sign `Digicam.entitlements.dev`).
/// - **Release:** real NFC + Family Controls (publisher team + `Digicam.entitlements`).
enum AppCapabilities {
    #if DEBUG
    static let useProductionEntitlements = false
    #else
    static let useProductionEntitlements = true
    #endif

    static var usesNFC: Bool { useProductionEntitlements }
    static var usesFamilyControls: Bool { useProductionEntitlements }
}
