import Foundation

@MainActor
final class IYSOStateManager: ObservableObject {
    static let shared = IYSOStateManager()

    @Published private(set) var isIYSOActive: Bool = false

    private init() {}

    func enterIYSOMode() {
        isIYSOActive = true
        // Shield activation is deferred to AppRootView's onChange(of: camera.isSessionRunning).
        // Calling applyShields() here races with session.startRunning() in Release builds:
        // ManagedSettingsStore talks to mediaserverd (camera daemon) to register restrictions,
        // and that IPC can interrupt a camera session that is mid-startup, leaving
        // isSessionRunning permanently false. Activating only after the session is confirmed
        // running eliminates the race entirely.
    }

    func activateShields() {
        Task {
            await AppBlockingManager.shared.activateShieldsForIYSOMode()
        }
    }

    func exitIYSOMode() {
        AppBlockingManager.shared.setShieldsActive(false)
        isIYSOActive = false
    }
}
