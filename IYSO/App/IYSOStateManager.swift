import Foundation

@MainActor
final class IYSOStateManager: ObservableObject {
    static let shared = IYSOStateManager()

    @Published private(set) var isIYSOActive: Bool = false

    private init() {}

    func enterIYSOMode() {
        isIYSOActive = true
        // AppRootView applies shields before starting the capture session. ManagedSettingsStore
        // can interrupt camera startup/capture readiness if it runs while AVCaptureSession is live.
    }

    func activateShields() async {
        guard isIYSOActive else { return }
        await AppBlockingManager.shared.activateShieldsForIYSOMode()
        guard !Task.isCancelled else { return }
        if !isIYSOActive {
            AppBlockingManager.shared.setShieldsActive(false)
        }
    }

    func exitIYSOMode() {
        AppBlockingManager.shared.setShieldsActive(false)
        isIYSOActive = false
    }
}
