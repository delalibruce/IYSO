import SwiftUI
import UIKit

#if DEBUG
private let showPeepholeTestScreen = false
#endif

@main
struct DigicamApp: App {
    @UIApplicationDelegateAdaptor(IYSOAppDelegate.self) private var appDelegate

    init() {
        IYSOFont.registerFonts()
        IYSOReturnNotificationCenter.requestPermissionIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if showPeepholeTestScreen {
                PeepholeAlbumCoverTestView()
            } else {
                AppRootView()
            }
            #else
            AppRootView()
            #endif
        }
    }
}
