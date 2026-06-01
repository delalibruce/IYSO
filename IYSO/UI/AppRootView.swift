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
    @State private var onboardingHitTestEnabled = true

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
                    library: library,
                    isLaunchLoadingComplete: !isShowingLaunchLoading
                ) {
                    onboardingHitTestEnabled = false
                    hasCompletedOnboarding = true
                    library.refreshAuthorizationStatusAndLoadIfAuthorized()
                }
                .environmentObject(appBlocking)
                .allowsHitTesting(onboardingHitTestEnabled)
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
            library.refreshAuthorizationStatusAndLoadIfAuthorized()
            if hasCompletedOnboarding {
                openInDefaultCameraMode()
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
                if hasCompletedOnboarding {
                    handleReturnToCameraIfNeeded()
                    if appState.isIYSOMode {
                        IYSOStateManager.shared.enterIYSOMode()
                    }
                }
            case .inactive, .background:
                lastBackgroundedAtTimestamp = Date().timeIntervalSince1970
                if hasCompletedOnboarding, appState.isIYSOMode {
                    appBlocking.reinforceShieldsIfNeeded()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: appState.activeTab) { _ in
            syncCameraSession()
        }
        .onChange(of: hasCompletedOnboarding) { completed in
            if completed {
                openInDefaultCameraMode()
            } else {
                syncCameraSession()
            }
        }
        .onOpenURL { url in
            if handleIYSOURL(url) { return }
            handleUniversalLink(url)
        }
    }

    // MARK: - Camera session

    private func syncCameraSession() {
        guard hasCompletedOnboarding else {
            camera.stopSession()
            return
        }
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        GeometryReader { geo in
            let rootSize = Self.resolvedRootContainerSize(geo.size)
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                Group {
                    if appState.activeTab == .camera {
                        CameraView(
                            camera: camera,
                            onExitIYSOTapped: { appState.showExitIYSOModal = true }
                        )
                    } else {
                        GalleryRootView(library: library)
                    }
                }
                .frame(width: rootSize.width, height: rootSize.height)

                BottomToggle(
                    activeTab: $appState.activeTab,
                    onCameraRequested: handleCameraRequested,
                    onGalleryRequested: handleGalleryRequested
                )
                .padding(
                    .bottom,
                    BottomToggleLayout.detailAlignedScreenBottomInset(
                        safeAreaBottom: geo.safeAreaInsets.bottom
                    )
                )
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
            .frame(width: rootSize.width, height: rootSize.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: appState.activeTab)
        .animation(.easeInOut(duration: 0.22), value: appState.showEnterIYSOModeSheet)
        .animation(.easeInOut(duration: 0.22), value: appState.showExitIYSOModal)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environmentObject(appState)
        .environmentObject(appBlocking)
    }

    /// Release/TestFlight can occasionally report a transient zero root geometry size during tab mode transitions.
    /// Fall back to physical screen bounds so gallery/camera content never collapses to a 0x0 frame.
    private static func resolvedRootContainerSize(_ proposed: CGSize) -> CGSize {
        let screen = UIScreen.main.bounds.size
        return CGSize(
            width: max(proposed.width, screen.width),
            height: max(proposed.height, screen.height)
        )
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
        IYSOStateManager.shared.enterIYSOMode()
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
        IYSOStateManager.shared.enterIYSOMode()
        syncCameraSession()
    }

    private func handleReturnToCameraIfNeeded() {
        guard appBlocking.consumeOpenCameraRequest() else { return }
        if !appState.isIYSOMode {
            enterIYSOMode()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.activeTab = .camera
            }
            IYSOStateManager.shared.enterIYSOMode()
        }
    }

    @discardableResult
    private func handleIYSOURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "iyso" else { return false }
        guard hasCompletedOnboarding else { return true }
        enterIYSOMode()
        return true
    }

    private func handleUniversalLink(_ url: URL) {
        guard url.host == "iyso.app" || url.host == "www.iyso.app",
              url.path == "/open" else { return }
        hasCompletedOnboarding = true
        enterIYSOMode()
    }
}
