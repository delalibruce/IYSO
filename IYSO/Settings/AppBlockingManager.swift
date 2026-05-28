import Foundation
import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

// App/category blocking is enforced through FamilyActivitySelection tokens.

@MainActor
final class AppBlockingManager: ObservableObject {
    static let shared = AppBlockingManager()
    @Published var blockedApps: [BlockedApp] = []
    @Published var isAuthorized: Bool = false
    #if canImport(FamilyControls)
    @Published var familyActivitySelection = FamilyActivitySelection()
    #endif

    #if canImport(FamilyControls)
    private let store = ManagedSettingsStore()
    #endif
    private let udKey = "com.delali.digicam.blockedApps"
    private let familySelectionUDKey = "com.delali.digicam.familyActivitySelection"

    init() {
        blockedApps = BlockedApp.installedDefaults
        loadSavedApps()
        if AppCapabilities.usesFamilyControls {
            loadFamilyActivitySelection()
            refreshAuthorizationStatus()
        } else {
            isAuthorized = true
        }
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        guard AppCapabilities.usesFamilyControls else {
            isAuthorized = true
            return
        }
        refreshAuthorizationStatus()
        guard !isAuthorized else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    func refreshAuthorizationStatus() {
        guard AppCapabilities.usesFamilyControls else {
            isAuthorized = true
            return
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: - Shields

    private(set) var shieldsShouldBeActive = false

    func setShieldsActive(_ active: Bool) {
        shieldsShouldBeActive = active
        if active {
            applyShields()
        } else {
            removeShields()
        }
    }

    func applyShields() {
        guard AppCapabilities.usesFamilyControls else { return }
        guard isAuthorized else { return }
        #if canImport(FamilyControls)
        store.shield.applications = familyActivitySelection.applicationTokens.isEmpty
            ? nil
            : familyActivitySelection.applicationTokens
        store.shield.webDomains = familyActivitySelection.webDomainTokens.isEmpty
            ? nil
            : familyActivitySelection.webDomainTokens
        store.shield.applicationCategories = familyActivitySelection.categoryTokens.isEmpty
            ? nil
            : .specific(familyActivitySelection.categoryTokens)
        #endif
    }

    func removeShields() {
        guard AppCapabilities.usesFamilyControls else { return }
        #if canImport(FamilyControls)
        store.clearAllSettings()
        #endif
    }

    // MARK: - FamilyActivitySelection

    #if canImport(FamilyControls)
    func loadBlockList() -> FamilyActivitySelection? {
        guard let data = UserDefaults.standard.data(forKey: familySelectionUDKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return nil }
        return selection
    }

    func saveBlockList(_ selection: FamilyActivitySelection) {
        familyActivitySelection = selection
        saveFamilyActivitySelection()
    }

    func updateFamilyActivitySelection(_ selection: FamilyActivitySelection) {
        familyActivitySelection = selection
        saveFamilyActivitySelection()
        if shieldsShouldBeActive {
            applyShields()
        }
    }

    var selectedItemCount: Int {
        familyActivitySelection.applicationTokens.count
            + familyActivitySelection.categoryTokens.count
            + familyActivitySelection.webDomainTokens.count
    }

    private func saveFamilyActivitySelection() {
        guard let data = try? PropertyListEncoder().encode(familyActivitySelection) else { return }
        UserDefaults.standard.set(data, forKey: familySelectionUDKey)
    }

    private func loadFamilyActivitySelection() {
        guard let data = UserDefaults.standard.data(forKey: familySelectionUDKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        familyActivitySelection = selection
    }
    #else
    private func loadFamilyActivitySelection() {}
    #endif

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
        blockedApps = mergedWithDefaultMetadata(savedApps: apps)
    }

    private func mergedWithDefaultMetadata(savedApps: [BlockedApp]) -> [BlockedApp] {
        let savedByID = Dictionary(uniqueKeysWithValues: savedApps.map { ($0.id, $0) })

        return BlockedApp.installedDefaults.map { defaultApp in
            guard let savedApp = savedByID[defaultApp.id] else {
                return defaultApp
            }

            // Keep persisted toggle state, but always use current metadata from defaults.
            return BlockedApp(
                id: defaultApp.id,
                name: defaultApp.name,
                isEnabled: savedApp.isEnabled,
                isDefault: defaultApp.isDefault,
                iconURLString: defaultApp.iconURLString,
                symbolName: defaultApp.symbolName
            )
        }
    }
}
