import SwiftUI

final class AppState: ObservableObject {
    @Published var isAlbumSelecting = false
    @Published var isGallerySearchPresented = false
    @Published var isPhotoDetailPresented = false
    @Published var activeTab: AppTab = .camera
    @Published var isIYSOMode: Bool = true
    @Published var showEnterIYSOModeSheet: Bool = false
    @Published var showExitIYSOModal: Bool = false
}

struct AppRootView: View {
    #if DEBUG
    /// Keep `false` for normal Debug runs; temporary onboarding resets can use launch args.
    private static let resetOnboardingEveryDebugLaunch = false
    #endif

    @StateObject private var camera = CameraManager()
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var appState = AppState()
    @ObservedObject private var appBlocking = AppBlockingManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasShownInitialLaunchLoading") private var hasShownInitialLaunchLoading = false
    @AppStorage("lastBackgroundedAtTimestamp") private var lastBackgroundedAtTimestamp: Double = 0
    @State private var isShowingLaunchLoading = true
    @State private var currentLaunchLoadingDuration = IYSOLoadingConfig.displayDuration
    @State private var isCurrentLoadingFirstLaunch = false
    @State private var hasAppeared = false
    @State private var launchLoadingDismissTask: Task<Void, Never>?

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
                    appBlocking: appBlocking,
                    isLaunchLoadingComplete: !isShowingLaunchLoading
                ) {
                    hasCompletedOnboarding = true
                    library.requestAccessAndLoad()
                    openInDefaultCameraMode()
                }
                .transition(.opacity)
                .zIndex(1000)
            }

            if isShowingLaunchLoading {
                IYSOLoadingScreen(
                    displayDuration: currentLaunchLoadingDuration,
                    usesSlowFirstLaunchProgress: isCurrentLoadingFirstLaunch
                )
                    .transition(.opacity)
                    .zIndex(2000)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.55), value: isShowingLaunchLoading)
        .onAppear {
            #if DEBUG
            if Self.resetOnboardingEveryDebugLaunch
                || DebugOverrides.resetOnboarding {
                hasCompletedOnboarding = false
            }
            #endif
            if hasCompletedOnboarding {
                library.requestAccessAndLoad()
                openInDefaultCameraMode()
            } else {
                library.refreshAuthorizationStatusAndLoadIfAuthorized()
            }
            presentLaunchLoading()
            syncCameraSession()
            hasAppeared = true
        }
        .onChange(of: scenePhase) { phase in
            guard hasAppeared else { return }
            switch phase {
            case .active:
                if shouldShowLoadingAfterInactivity() {
                    presentLaunchLoading()
                }
                if hasCompletedOnboarding, appState.isIYSOMode {
                    IYSOStateManager.shared.enterIYSOMode()
                }
            case .inactive, .background:
                lastBackgroundedAtTimestamp = Date().timeIntervalSince1970
            @unknown default:
                break
            }
        }
        .onChange(of: appState.activeTab) { _ in
            syncCameraSession()
        }
        .onOpenURL { url in
            handleUniversalLink(url)
        }
        .task {
            await appBlocking.requestAuthorizationIfNeeded()
        }
    }

    // MARK: - Camera session

    private func syncCameraSession() {
        if appState.activeTab == .camera {
            camera.startSession()
        } else {
            camera.stopSession()
        }
    }

    // MARK: - Launch loading

    private func presentLaunchLoading() {
        let behavior = nextLaunchLoadingBehavior()
        currentLaunchLoadingDuration = behavior.duration
        isCurrentLoadingFirstLaunch = behavior.isFirstLaunch
        isShowingLaunchLoading = true
        dismissLaunchLoadingIfNeeded()
    }

    private func dismissLaunchLoadingIfNeeded() {
        let duration = currentLaunchLoadingDuration
        launchLoadingDismissTask?.cancel()
        guard isShowingLaunchLoading, IYSOLoadingConfig.autoDismisses else { return }
        launchLoadingDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    isShowingLaunchLoading = false
                }
            }
        }
    }

    private func nextLaunchLoadingBehavior() -> (duration: TimeInterval, isFirstLaunch: Bool) {
        let isFirstEverOpen = !hasCompletedOnboarding && !hasShownInitialLaunchLoading
        if isFirstEverOpen {
            hasShownInitialLaunchLoading = true
            return (IYSOLoadingConfig.firstLaunchDisplayDuration, true)
        }
        return (IYSOLoadingConfig.displayDuration, false)
    }

    private func shouldShowLoadingAfterInactivity() -> Bool {
        guard lastBackgroundedAtTimestamp > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - lastBackgroundedAtTimestamp
        return elapsed >= IYSOLoadingConfig.relaunchAfterIdleInterval
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

            if appState.showEnterIYSOModeSheet {
                EnterIYSOModeModal(
                    onEnter: enterIYSOMode,
                    onCancel: { appState.showEnterIYSOModeSheet = false }
                )
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
        .animation(.easeInOut(duration: 0.22), value: appState.showEnterIYSOModeSheet)
        .animation(.easeInOut(duration: 0.22), value: appState.showExitIYSOModal)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environmentObject(appState)
        .environmentObject(appBlocking)
    }

    // MARK: - Mode transitions

    private func handleCameraRequested() {
        if appState.isIYSOMode {
            withAnimation(.easeInOut(duration: 0.2)) { appState.activeTab = .camera }
        } else {
            appState.showEnterIYSOModeSheet = true
        }
    }

    private func handleGalleryRequested() {
        if appState.isIYSOMode {
            appState.showExitIYSOModal = true
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { appState.activeTab = .gallery }
        }
    }

    private func enterIYSOMode() {
        appState.showEnterIYSOModeSheet = false
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.activeTab = .camera
            appState.isIYSOMode = true
        }
        Task {
            await appBlocking.requestAuthorizationIfNeeded()
            IYSOStateManager.shared.enterIYSOMode()
        }
    }

    private func exitIYSOMode() {
        appState.showExitIYSOModal = false
        withAnimation(.easeInOut(duration: 0.2)) {
            appState.isIYSOMode = false
            appState.activeTab = .gallery
        }
        IYSOStateManager.shared.exitIYSOMode()
    }

    private func openInDefaultCameraMode() {
        appState.showEnterIYSOModeSheet = false
        appState.showExitIYSOModal = false
        appState.activeTab = .camera
        appState.isIYSOMode = true
        Task {
            await appBlocking.requestAuthorizationIfNeeded()
            IYSOStateManager.shared.enterIYSOMode()
        }
        syncCameraSession()
    }

    private func handleUniversalLink(_ url: URL) {
        guard url.host == "iyso.app" || url.host == "www.iyso.app",
              url.path == "/open" else { return }
        hasCompletedOnboarding = true
        enterIYSOMode()
    }
}
