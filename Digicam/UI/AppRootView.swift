import SwiftUI

final class AppState: ObservableObject {
    @Published var isAlbumSelecting = false
    @Published var isGallerySearchPresented = false
    @Published var isPhotoDetailPresented = false
    @Published var activeTab: AppTab = .camera
}

struct AppRootView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var appState = AppState()
    /// Hide the root toggle only on gallery overlays; keep it visible on camera so
    /// Memory ↔ Camera still works after opening photo detail (detail has its own toggle in-gallery).
    private var hidesBottomToggle: Bool {
        guard appState.activeTab == .gallery else { return false }
        return appState.isAlbumSelecting
            || appState.isGallerySearchPresented
            || appState.isPhotoDetailPresented
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            CameraView(camera: camera)
                .opacity(appState.activeTab == .camera ? 1 : 0)
                .allowsHitTesting(appState.activeTab == .camera)

            GalleryRootView(library: library)
                .opacity(appState.activeTab == .gallery ? 1 : 0)
                .allowsHitTesting(appState.activeTab == .gallery)

            BottomToggle(activeTab: $appState.activeTab)
                .padding(.bottom, BottomToggleLayout.bottomPadding)
                .zIndex(100)
                .ignoresSafeArea(.keyboard)
                .opacity(hidesBottomToggle ? 0 : 1)
                .allowsHitTesting(!hidesBottomToggle)
                .animation(.easeInOut(duration: 0.2), value: hidesBottomToggle)
        }
        .animation(.easeInOut(duration: 0.2), value: appState.activeTab)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environmentObject(appState)
        .onAppear {
            camera.requestPermissionsAndStart()
            library.requestAccessAndLoad()
        }
    }
}
