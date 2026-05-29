import Foundation

@MainActor
final class IYSOStateManager: ObservableObject {
    static let shared = IYSOStateManager()

    @Published private(set) var isIYSOActive: Bool = false

    private init() {}

    func enterIYSOMode() {
        isIYSOActive = true
    }

    func exitIYSOMode() {
        isIYSOActive = false
    }
}
