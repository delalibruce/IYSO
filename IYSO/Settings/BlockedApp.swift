import Foundation
import UIKit

struct BlockedApp: Identifiable, Codable {
    let id: String
    let name: String
    var isEnabled: Bool
    let isDefault: Bool
    let iconURLString: String?
    let symbolName: String?

    init(
        id: String,
        name: String,
        isEnabled: Bool,
        isDefault: Bool,
        iconURLString: String? = nil,
        symbolName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.iconURLString = iconURLString
        self.symbolName = symbolName
    }

    // URL schemes used to detect whether the app is installed.
    // nil = system app, always present.
    private static let urlSchemes: [String: String] = [
        "com.zhiliaoapp.musically": "tiktok://",
        "com.burbn.instagram":      "instagram://",
        "com.google.ios.youtube":   "youtube://",
        "com.toyopagroup.picaboo":  "snapchat://",
    ]

    var isInstalled: Bool {
        guard let scheme = BlockedApp.urlSchemes[id],
              let url = URL(string: scheme) else { return true }
        return UIApplication.shared.canOpenURL(url)
    }

    static let defaults: [BlockedApp] = [
        BlockedApp(id: "com.zhiliaoapp.musically", name: "TikTok",     isEnabled: true, isDefault: true),
        BlockedApp(id: "com.burbn.instagram",      name: "Instagram",  isEnabled: true, isDefault: true),
        BlockedApp(id: "com.apple.MobileSMS",      name: "Messages",   isEnabled: true, isDefault: true, symbolName: "message.fill"),
        BlockedApp(id: "com.apple.mobilesafari",   name: "Safari",     isEnabled: true, isDefault: true, symbolName: "safari.fill"),
        BlockedApp(id: "com.google.ios.youtube",   name: "YouTube",    isEnabled: true, isDefault: true),
        BlockedApp(id: "com.toyopagroup.picaboo",  name: "Snapchat",   isEnabled: true, isDefault: true),
    ]

    @MainActor
    static var installedDefaults: [BlockedApp] {
        defaults.filter { $0.isInstalled }
    }
}
