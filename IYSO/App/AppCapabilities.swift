import Foundation

/// Feature flags for entitlement-gated capabilities.
enum AppCapabilities {
    /// NFC lens detection is paused (code archived under `IYSO/Archived/NFC/`).
    static var usesNFC: Bool { false }

    /// Screen Time / Family Controls shields (Release + TestFlight).
    static var usesFamilyControls: Bool { true }
}
