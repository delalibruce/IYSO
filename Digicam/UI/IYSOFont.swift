import CoreText
import SwiftUI
import UIKit

enum IYSOFont {
    /// PostScript name inside BootzyTM.ttf
    static let bootzyPostScriptName = "BootzyTM"

    /// Call once at launch so bundled BootzyTM is available to SwiftUI.
    static func registerFonts() {
        let urls = [
            Bundle.main.url(forResource: "BootzyTM", withExtension: "ttf", subdirectory: "Fonts"),
            Bundle.main.url(forResource: "BootzyTM", withExtension: "ttf"),
        ].compactMap { $0 }

        for url in urls {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    static func bootzy(size: CGFloat) -> Font {
        if let uiFont = UIFont(name: bootzyPostScriptName, size: size) {
            return Font(uiFont)
        }
        return .custom(bootzyPostScriptName, size: size)
    }

    /// Letter spacing as a percentage of the font size (e.g. 8 → 8% → `.tracking` points).
    static func tracking(percentOfFontSize percent: CGFloat, fontSize: CGFloat) -> CGFloat {
        fontSize * percent / 100
    }
}
