import CoreText
import SwiftUI
import UIKit

enum IYSOFont {
    /// PostScript name inside BootzyTM.ttf
    static let bootzyPostScriptName = "BootzyTM"
    /// PostScript name inside Inter-Regular.ttf
    static let interRegularPostScriptName = "Inter-Regular"

    /// Call once at launch so bundled fonts are available to SwiftUI.
    static func registerFonts() {
        let resources: [(name: String, ext: String)] = [
            ("BootzyTM", "ttf"),
            ("Inter-Regular", "ttf"),
        ]

        for resource in resources {
            let urls = [
                Bundle.main.url(forResource: resource.name, withExtension: resource.ext, subdirectory: "Fonts"),
                Bundle.main.url(forResource: resource.name, withExtension: resource.ext),
            ].compactMap { $0 }

            for url in urls {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
    }

    static func bootzy(size: CGFloat) -> Font {
        customFont(postScriptName: bootzyPostScriptName, size: size)
    }

    static func inter(size: CGFloat) -> Font {
        customFont(postScriptName: interRegularPostScriptName, size: size)
    }

    private static func customFont(postScriptName: String, size: CGFloat) -> Font {
        if let uiFont = UIFont(name: postScriptName, size: size) {
            return Font(uiFont)
        }
        return .custom(postScriptName, size: size)
    }

    /// Letter spacing as a percentage of the font size (e.g. 8 → 8% → `.tracking` points).
    static func tracking(percentOfFontSize percent: CGFloat, fontSize: CGFloat) -> CGFloat {
        fontSize * percent / 100
    }
}
