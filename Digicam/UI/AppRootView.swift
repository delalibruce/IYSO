import SwiftUI

final class AppState: ObservableObject {
    @Published var isAlbumSelecting = false
}

struct AppRootView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var appState = AppState()
    @State private var activeTab: AppTab = .camera

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            CameraView(camera: camera)
                .opacity(activeTab == .camera ? 1 : 0)
                .allowsHitTesting(activeTab == .camera)

            GalleryRootView(library: library)
                .opacity(activeTab == .gallery ? 1 : 0)
                .allowsHitTesting(activeTab == .gallery)

            BottomToggle(activeTab: $activeTab)
                .padding(.bottom, 20)
                .ignoresSafeArea(.keyboard)
                .opacity(appState.isAlbumSelecting ? 0 : 1)
                .allowsHitTesting(!appState.isAlbumSelecting)
        }
        .animation(.easeInOut(duration: 0.2), value: activeTab)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environmentObject(appState)
        .onAppear {
            camera.requestPermissionsAndStart()
            library.requestAccessAndLoad()
        }
    }
}
