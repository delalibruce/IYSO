import Foundation

@MainActor
final class IYSOStateManager: ObservableObject {
    static let shared = IYSOStateManager()

    @Published private(set) var isIYSOActive: Bool = false

    private init() {}

    func enterIYSOMode() {
        AppBlockingManager.shared.setShieldsActive(true)
        isIYSOActive = true
    }

    func exitIYSOMode() {
        AppBlockingManager.shared.setShieldsActive(false)
        isIYSOActive = false
    }
}
