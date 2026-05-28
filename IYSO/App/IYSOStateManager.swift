import Foundation

@MainActor
final class IYSOStateManager: ObservableObject {
    static let shared = IYSOStateManager()

    @Published var isIYSOActive: Bool = false

    private let blocking = AppBlockingManager()

    private init() {}

    func enterIYSOMode() {
        blocking.applyShields()
        isIYSOActive = true
    }

    func exitIYSOMode() {
        blocking.removeShields()
        isIYSOActive = false
    }
}
