import SwiftUI

#if DEBUG
private let showPeepholeTestScreen = false
#endif

@main
struct DigicamApp: App {
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
