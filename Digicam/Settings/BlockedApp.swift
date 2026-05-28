import Foundation

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

    static let defaults: [BlockedApp] = [
        BlockedApp(
            id: "com.zhiliaoapp.musically",
            name: "TikTok",
            isEnabled: true,
            isDefault: true
        ),
        BlockedApp(
            id: "com.burbn.instagram",
            name: "Instagram",
            isEnabled: true,
            isDefault: true
        ),
        BlockedApp(
            id: "com.apple.MobileSMS",
            name: "Messages",
            isEnabled: true,
            isDefault: true,
            symbolName: "message.fill"
        ),
        BlockedApp(
            id: "com.apple.mobilesafari",
            name: "Safari",
            isEnabled: true,
            isDefault: true,
            symbolName: "safari.fill"
        ),
        BlockedApp(
            id: "com.google.ios.youtube",
            name: "YouTube",
            isEnabled: true,
            isDefault: true
        ),
        BlockedApp(
            id: "com.toyopagroup.picaboo",
            name: "Snapchat",
            isEnabled: true,
            isDefault: true
        ),
    ]
}
