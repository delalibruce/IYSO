import Foundation

/// Feature flags for entitlement-gated capabilities.
enum AppCapabilities {
    /// NFC lens detection is paused (code archived under `IYSO/Archived/NFC/`).
    static var usesNFC: Bool { false }
}
