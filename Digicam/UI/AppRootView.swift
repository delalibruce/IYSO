import SwiftUI

final class AppState: ObservableObject {
    @Published var isAlbumSelecting = false
    @Published var isGallerySearchPresented = false
    @Published var isPhotoDetailPresented = false
    @Published var activeTab: AppTab = .gallery
    @Published var isIYSOMode: Bool = false
    @Published var showAttachLensSheet: Bool = false
    @Published var showExitIYSOModal: Bool = false
    @Published var showLensDetectedBanner: Bool = false
}

struct AppRootView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var appState = AppState()
    @StateObject private var nfc = NFCManager()
    @StateObject private var appBlocking = AppBlockingManager()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isShowingLaunchLoading = true

    private var hidesBottomToggle: Bool {
        guard appState.activeTab == .gallery else { return false }
        return appState.isAlbumSelecting
            || appState.isGallerySearchPresented
            || appState.isPhotoDetailPresented
    }

    var body: some View {
        ZStack {
            mainApp

            if !hasCompletedOnboarding {
                OnboardingFlowView(
                    nfc: nfc,
                    appBlocking: appBlocking,
                    isLaunchLoadingComplete: !isShowingLaunchLoading
                ) { enteredIYSOMode in
                    hasCompletedOnboarding = true
                    if enteredIYSOMode {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.activeTab = .camera
                            appState.isIYSOMode = true
                        }
                        appBlocking.applyShields()
                    }
                }
                .transition(.opacity)
                .zIndex(1000)
            }

            if isShowingLaunchLoading {
                IYSOLoadingScreen()
                    .transition(.opacity)
                    .zIndex(2000)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.55), value: isShowingLaunchLoading)
        .onAppear {
            camera.requestPermissionsAndStart()
            library.requestAccessAndLoad()
            if hasCompletedOnboarding, AppCapabilities.usesNFC { nfc.scanOnLaunch() }
            dismissLaunchLoadingIfNeeded()
        }
        .onChange(of: nfc.scanState) { state in
            guard AppCapabilities.usesNFC, state == .detected, hasCompletedOnboarding else { return }
            handleLensDetected()
        }
    }

    // MARK: - Launch loading

    private func dismissLaunchLoadingIfNeeded() {
        guard isShowingLaunchLoading else { return }
        Task {
            try? await Task.sleep(for: .seconds(IYSOLoadingConfig.displayDuration))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    isShowingLaunchLoading = false
                }
            }
        }
    }

    // MARK: - Main app

    private var mainApp: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            CameraView(
                camera: camera,
                onExitIYSOTapped: { appState.showExitIYSOModal = true }
            )
            .opacity(appState.activeTab == .camera ? 1 : 0)
            .allowsHitTesting(appState.activeTab == .camera)

            GalleryRootView(library: library)
                .opacity(appState.activeTab == .gallery ? 1 : 0)
                .allowsHitTesting(appState.activeTab == .gallery)

            BottomToggle(
                activeTab: $appState.activeTab,
                onCameraRequested: handleCameraRequested,
                onGalleryRequested: handleGalleryRequested
            )
            .padding(.bottom, BottomToggleLayout.bottomPadding)
            .zIndex(100)
            .ignoresSafeArea(.keyboard)
            .opacity(hidesBottomToggle ? 0 : 1)
            .allowsHitTesting(!hidesBottomToggle)
            .animation(.easeInOut(duration: 0.2), value: hidesBottomToggle)

            if appState.showAttachLensSheet {
                AttachLensModal()
                    .transition(.opacity)
                    .zIndex(200)
            }

            if appState.showExitIYSOModal {
                ExitIYSOModal(
                    onExit: exitIYSOMode,
                    onKeepShooting: { appState.showExitIYSOModal = false }
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.activeTab)
        .animation(.easeInOut(duration: 0.22), value: appState.showAttachLensSheet)
        .animation(.easeInOut(duration: 0.22), value: appState.showExitIYSOModal)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environmentObject(appState)
        .environmentObject(nfc)
        .environmentObject(appBlocking)
    }

    // MARK: - Mode transitions

    private func handleCameraRequested() {
        if !AppCapabilities.usesNFC || appState.isIYSOMode || nfc.isLensConnected {
            withAnimation(.easeInOut(duration: 0.2)) { appState.activeTab = .camera }
        } else {
            appState.showAttachLensSheet = true
        }
    }

    private func handleGalleryRequested() {
        if appState.isIYSOMode {
            appState.showExitIYSOModal = true
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { appState.activeTab = .gallery }
        }
    }

    private func handleLensDetected() {
        appState.showAttachLensSheet = false
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.activeTab = .camera
            appState.isIYSOMode = true
        }
        appBlocking.applyShields()
        appState.showLensDetectedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                appState.showLensDetectedBanner = false
            }
        }
    }

    private func exitIYSOMode() {
        appState.showExitIYSOModal = false
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.isIYSOMode = false
            appState.activeTab = .gallery
        }
        nfc.disconnectLens()
        appBlocking.removeShields()
    }
}
