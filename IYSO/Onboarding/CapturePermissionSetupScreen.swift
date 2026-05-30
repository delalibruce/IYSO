import AVFoundation
import Photos
import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

// MARK: - Permission state

enum CapturePermissionAccess: Equatable {
    case notDetermined
    case authorized
    case denied

    static func camera() -> CapturePermissionAccess {
        #if DEBUG
        if DebugOverrides.forceDeniedCamera { return .denied }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    static func photos() -> CapturePermissionAccess {
        #if DEBUG
        if DebugOverrides.forceDeniedPhotos { return .denied }
        #endif
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    static func screenTime() -> CapturePermissionAccess {
        guard AppCapabilities.usesFamilyControls else { return .authorized }
        #if canImport(FamilyControls)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .denied
        }
        #else
        return .authorized
        #endif
    }
}

// MARK: - Screen

struct CapturePermissionSetupScreen: View {
    let onContinue: () -> Void

    @EnvironmentObject private var appBlocking: AppBlockingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraAccess = CapturePermissionAccess.camera()
    @State private var photosAccess = CapturePermissionAccess.photos()
    @State private var notificationsAccess = CapturePermissionAccess.notDetermined
    @State private var screenTimeAccess = CapturePermissionAccess.screenTime()
    @State private var isRequestingCamera = false
    @State private var isRequestingPhotos = false
    @State private var isRequestingNotifications = false
    @State private var isRequestingScreenTime = false

    private var allGranted: Bool {
        cameraAccess == .authorized
            && photosAccess == .authorized
            && notificationsAccess == .authorized
            && screenTimeAccess == .authorized
    }

    private var hasDeniedPermission: Bool {
        cameraAccess == .denied
            || photosAccess == .denied
            || notificationsAccess == .denied
            || screenTimeAccess == .denied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerText

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        permissionCards
                        if hasDeniedPermission {
                            settingsHint
                        }
                    }
                    .padding(.bottom, 120)
                }

                continueButton
            }
        }
        .onAppear { refreshPermissionState() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshPermissionState() }
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set up capture")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("IYSO needs access to your camera, photos, notifications, and Screen Time to create your memory card and keep you focused while shooting.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Cards

    private var permissionCards: some View {
        VStack(spacing: 12) {
            CapturePermissionRow(
                title: "Camera",
                subtitle: "take photos through your lens.",
                systemImage: "camera.fill",
                access: cameraAccess,
                isLoading: isRequestingCamera,
                enableLabel: "Enable Camera",
                onEnable: requestCameraAccess
            )

            CapturePermissionRow(
                title: "Photos",
                subtitle: "save and show your IYSO captures in your memory card.",
                systemImage: "photo.on.rectangle.angled",
                access: photosAccess,
                isLoading: isRequestingPhotos,
                enableLabel: "Enable Photos",
                onEnable: requestPhotosAccess
            )

            CapturePermissionRow(
                title: "Notifications",
                subtitle: "get a nudge to return to IYSO when you leave the app.",
                systemImage: "bell.fill",
                access: notificationsAccess,
                isLoading: isRequestingNotifications,
                enableLabel: "Enable Notifications",
                onEnable: requestNotificationsAccess
            )

            if AppCapabilities.usesFamilyControls {
                CapturePermissionRow(
                    title: "Screen Time",
                    subtitle: "enable screen time access.",
                    systemImage: "hourglass",
                    access: screenTimeAccess,
                    isLoading: isRequestingScreenTime,
                    enableLabel: "Enable Screen Time",
                    onEnable: requestScreenTimeAccess
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var settingsHint: some View {
        Text("You can turn on access later in Settings.")
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(Color(white: 0.4))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .padding(.top, 16)
    }

    // MARK: - Continue

    private var continueButton: some View {
        OnboardingContinueButton(isEnabled: allGranted, action: onContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.4)
                )
                .ignoresSafeArea()
            )
            .animation(.easeInOut(duration: 0.15), value: allGranted)
    }

    // MARK: - Requests

    private func refreshPermissionState() {
        cameraAccess = CapturePermissionAccess.camera()
        photosAccess = CapturePermissionAccess.photos()
        appBlocking.refreshAuthorizationStatus()
        screenTimeAccess = CapturePermissionAccess.screenTime()
        Task {
            let access = await IYSOReturnNotificationCenter.currentAccess()
            await MainActor.run {
                notificationsAccess = access
            }
        }
    }

    private func requestCameraAccess() {
        switch cameraAccess {
        case .authorized:
            return
        case .denied:
            openAppSettings()
            return
        case .notDetermined:
            guard !isRequestingCamera else { return }
            isRequestingCamera = true
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    isRequestingCamera = false
                    cameraAccess = CapturePermissionAccess.camera()
                }
            }
        }
    }

    private func requestPhotosAccess() {
        switch photosAccess {
        case .authorized:
            return
        case .denied:
            openAppSettings()
            return
        case .notDetermined:
            guard !isRequestingPhotos else { return }
            isRequestingPhotos = true
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async {
                    isRequestingPhotos = false
                    photosAccess = CapturePermissionAccess.photos()
                }
            }
        }
    }

    private func requestNotificationsAccess() {
        switch notificationsAccess {
        case .authorized:
            return
        case .denied:
            openAppSettings()
            return
        case .notDetermined:
            guard !isRequestingNotifications else { return }
            isRequestingNotifications = true
            Task {
                let access = await IYSOReturnNotificationCenter.requestAuthorization()
                await MainActor.run {
                    isRequestingNotifications = false
                    notificationsAccess = access
                }
            }
        }
    }

    private func requestScreenTimeAccess() {
        switch screenTimeAccess {
        case .authorized:
            return
        case .denied:
            openAppSettings()
            return
        case .notDetermined:
            guard !isRequestingScreenTime else { return }
            isRequestingScreenTime = true
            Task {
                await appBlocking.requestAuthorizationIfNeeded()
                await MainActor.run {
                    isRequestingScreenTime = false
                    screenTimeAccess = CapturePermissionAccess.screenTime()
                }
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Row

private struct CapturePermissionRow: View {
    private static let cardPadding: CGFloat = 16
    private static let iconSize: CGFloat = 44
    private static let iconToTextSpacing: CGFloat = 12
    /// Shared size for enable, enabled, and denied controls across all cards.
    private static let actionControlWidth: CGFloat = 108
    private static let actionControlHeight: CGFloat = 36

    let title: String
    let subtitle: String
    let systemImage: String
    let access: CapturePermissionAccess
    let isLoading: Bool
    let enableLabel: String
    let onEnable: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Self.iconToTextSpacing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 1, opacity: 0.08))
                .frame(width: Self.iconSize, height: Self.iconSize)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            actionControl
                .frame(
                    width: Self.actionControlWidth,
                    height: Self.actionControlHeight,
                    alignment: .center
                )
        }
        .padding(Self.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 1, opacity: 0.05))
        )
    }

    @ViewBuilder
    private var actionControl: some View {
        switch access {
        case .authorized:
            enabledBadge
        case .denied:
            deniedBadge
        case .notDetermined:
            enableButton
        }
    }

    private var enableButton: some View {
        OnboardingContinueButton(
            title: "enable",
            layout: .compact,
            showsLoading: isLoading,
            action: onEnable
        )
        .accessibilityLabel(enableLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enabledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
            Text("Enabled")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.2, green: 0.45, blue: 0.28, opacity: 0.35))
        )
    }

    private var deniedBadge: some View {
        OnboardingContinueButton(
            title: "denied",
            muted: true,
            layout: .compact,
            action: onEnable
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
