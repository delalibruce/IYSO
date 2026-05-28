import Foundation

#if DEBUG
enum DebugOverrides {
    // MARK: - Onboarding

    static var resetOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-resetOnboarding")
    }

    // MARK: - Permissions

    static var forceDeniedCamera: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-forceDeniedPermissions") || args.contains("-forceDeniedCameraPermission")
    }

    static var forceDeniedPhotos: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-forceDeniedPermissions") || args.contains("-forceDeniedPhotosPermission")
    }

    static var suppressPermissionPrompts: Bool {
        // If we're forcing denied, also suppress any system permission prompts.
        forceDeniedCamera || forceDeniedPhotos || ProcessInfo.processInfo.arguments.contains("-suppressPermissionPrompts")
    }
}
#endif

