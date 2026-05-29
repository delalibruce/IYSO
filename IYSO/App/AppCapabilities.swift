import Foundation

/// Feature flags for entitlement-gated capabilities.
enum AppCapabilities {
    /// NFC lens detection is paused (code archived under `IYSO/Archived/NFC/`).
    static var usesNFC: Bool { false }

    /// Screen Time / Family Controls shields — disabled until Apple approves entitlement.
    static var usesFamilyControls: Bool { false }
}
