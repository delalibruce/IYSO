import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings

// ApplicationToken wiring requires FamilyActivityPicker (cannot create tokens from bundle IDs).
// v1: persists user selections and manages authorization. Shield application is a v2 task.

@MainActor
final class AppBlockingManager: ObservableObject {
    @Published var blockedApps: [BlockedApp] = BlockedApp.defaults
    @Published var isAuthorized: Bool = false

    private let store = ManagedSettingsStore()
    private let udKey = "com.delali.digicam.blockedApps"

    init() {
        loadSavedApps()
        refreshAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        guard !isAuthorized else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    private func refreshAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - Shields

    func applyShields() {
        // ApplicationToken-based shielding wired in v2 via FamilyActivityPicker.
        // Shield state is tracked; the store will be updated once tokens are available.
    }

    func removeShields() {
        store.clearAllSettings()
    }

    // MARK: - App list

    func toggleApp(_ app: BlockedApp) {
        guard let idx = blockedApps.firstIndex(where: { $0.id == app.id }) else { return }
        blockedApps[idx].isEnabled.toggle()
        saveApps()
    }

    func enabledBundleIDs() -> [String] {
        blockedApps.filter(\.isEnabled).map(\.id)
    }

    private func saveApps() {
        guard let data = try? JSONEncoder().encode(blockedApps) else { return }
        UserDefaults.standard.set(data, forKey: udKey)
    }

    private func loadSavedApps() {
        guard let data = UserDefaults.standard.data(forKey: udKey),
              let apps = try? JSONDecoder().decode([BlockedApp].self, from: data) else { return }
        blockedApps = apps
    }
}
