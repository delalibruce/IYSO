import SwiftUI

enum LensConnectionState {
    case idle
    case connecting
    case connected
    case failed
}

struct ExplainerConfig {
    let headline: String
    let body: String
    let illustrationSystemName: String
    let dotIndex: Int
    let dotTotal: Int
    let ctaLabel: String
    /// When set, shows the same mode pill as the camera / memory card headers.
    let modeBadge: AppMode?
    /// Replaces the SF Symbol with the lens-attach instructional animation.
    let showsLensAttachAnimation: Bool
    /// Replaces the SF Symbol with the IYSO shooting-mode instructional animation.
    let showsIYSOShootingModeAnimation: Bool
    /// Replaces the SF Symbol with the exit-IYSO → memory-card instructional animation.
    let showsExitIYSOAnimation: Bool
    /// When true, the mode badge dot is activated by the exit-IYSO animation tap.
    let drivesModeBadgeWithExitIYSOAnimation: Bool
    /// Reuses lens animation to show remove + reattach flow.
    let showsLensReattachAnimation: Bool
}

extension ExplainerConfig {
    static let lens = ExplainerConfig(
        headline: "Clip on your lens",
        body: "Camera mode starts when it connects.",
        illustrationSystemName: "camera.aperture",
        dotIndex: 1, dotTotal: 4,
        ctaLabel: "Connect Lens",
        modeBadge: .iyso,
        showsLensAttachAnimation: true,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsLensReattachAnimation: false
    )
    static let iysoMode = ExplainerConfig(
        headline: "IYSO Mode is for shooting",
        body: "Notifications off. Outside apps locked. Just you and the shot.",
        illustrationSystemName: "camera.fill",
        dotIndex: 2, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: nil,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: true,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsLensReattachAnimation: false
    )
    static let memoryMode = ExplainerConfig(
        headline: "Done shooting?",
        body: "Tap “Exit IYSO Mode” to unlock your memory card to view photos.",
        illustrationSystemName: "photo.stack.fill",
        dotIndex: 3, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: .memory,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: true,
        drivesModeBadgeWithExitIYSOAnimation: true,
        showsLensReattachAnimation: false
    )
    static let noPeeking = ExplainerConfig(
        headline: "Reattach to shoot again",
        body: "Remove your lens and reattach it to reconnect to IYSO Mode.",
        illustrationSystemName: "lock.fill",
        dotIndex: 4, dotTotal: 4,
        ctaLabel: "Got it",
        modeBadge: nil,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsLensReattachAnimation: true
    )
}

struct ExplainerFlowView: View {
    let onComplete: (_ connectedLens: Bool) -> Void
    let onBack: () -> Void

    @State private var page = 0
    @State private var lensConnectionState: LensConnectionState = .idle
    @State private var lensConnectedForOnboarding = false
    @State private var lensConnectionTask: Task<Void, Never>?

    private static let configs: [ExplainerConfig] = [.lens, .iysoMode, .memoryMode, .noPeeking]

    private var currentConfig: ExplainerConfig {
        Self.configs[page]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    OnboardingBackButton(action: handleBack)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Self.configs.indices, id: \.self) { index in
                        ExplainerScreen(
                            config: Self.configs[index],
                            lensConnectionState: index == 0 ? lensConnectionState : .idle
                        )
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 24) {
                    OnboardingProgressDots(total: currentConfig.dotTotal, current: page + 1)

                    if page == 0 {
                        firstPageControls
                            .padding(.horizontal, 24)
                    } else {
                        OnboardingContinueButton(
                            title: currentConfig.ctaLabel.lowercased(),
                            action: advanceFromButton
                        )
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onDisappear {
            lensConnectionTask?.cancel()
            lensConnectionTask = nil
        }
    }

    private func advanceFromButton() {
        if page < Self.configs.count - 1 {
            withAnimation(.easeInOut(duration: 0.28)) {
                page += 1
            }
        } else {
            onComplete(lensConnectedForOnboarding)
        }
    }

    private func handleBack() {
        if page > 0 {
            withAnimation(.easeInOut(duration: 0.28)) {
                page -= 1
            }
        } else {
            onBack()
        }
    }

    @ViewBuilder
    private var firstPageControls: some View {
        VStack(spacing: 16) {
            OnboardingContinueButton(
                title: primaryLensButtonTitle,
                isEnabled: lensConnectionState != .connecting,
                action: startLensConnection
            )

            Button(action: skipLensConnection) {
                Text("I don't have my lens yet")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
            }
            .buttonStyle(.plain)
            .disabled(lensConnectionState == .connecting)
            .opacity(lensConnectionState == .connecting ? 0.6 : 1.0)
        }
    }

    private var primaryLensButtonTitle: String {
        switch lensConnectionState {
        case .idle:
            return "Connect Lens"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Lens connected"
        case .failed:
            return "Retry connection"
        }
    }

    private func startLensConnection() {
        guard lensConnectionState != .connecting else { return }
        lensConnectionTask?.cancel()
        lensConnectionState = .connecting

        lensConnectionTask = Task {
            // TODO: Replace simulated connection with a CoreNFC reader session.
            // Keep this UI state machine and call `await onLensConnected()` when the real tag is detected.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await onLensConnected()
        }
    }

    @MainActor
    private func onLensConnected() async {
        lensConnectionState = .connected
        lensConnectedForOnboarding = true
        try? await Task.sleep(for: .seconds(1.7))
        guard !Task.isCancelled else { return }
        advanceFromButton()
    }

    private func skipLensConnection() {
        lensConnectionTask?.cancel()
        lensConnectionState = .idle
        lensConnectedForOnboarding = false
        advanceFromButton()
    }
}

private enum ExplainerTextLayout {
    static let headlineToBodySpacing: CGFloat = 10
}

struct ExplainerScreen: View {
    let config: ExplainerConfig
    var lensConnectionState: LensConnectionState = .idle

    @State private var isModeIndicatorActive = false

    var body: some View {
        // The 3rd instructional page (memory mode) needs the text slightly closer to the illustration.
        // This keeps the headline/body stack balanced with the larger exit-IYSO animation.
        let illustrationToTextSpacing: CGFloat = (config.dotIndex == 3) ? 40 : 48
        let contentVerticalOffset: CGFloat = (config.dotIndex == 3) ? -12 : 0

        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: illustrationToTextSpacing) {
                illustration

                VStack(alignment: .leading, spacing: ExplainerTextLayout.headlineToBodySpacing) {
                    VStack(alignment: .leading, spacing: RootTabHeaderLayout.modeLabelToTitleSpacing) {
                        if let mode = config.modeBadge {
                            ModeBadge(
                                mode: mode,
                                isIndicatorActive: (config.showsLensAttachAnimation
                                    || config.drivesModeBadgeWithExitIYSOAnimation)
                                    ? isModeIndicatorActive
                                    : true
                            )
                        }

                        Text(config.headline)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(config.body)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(white: 0.55))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
            }
            .offset(y: contentVerticalOffset)

            Spacer()
        }
    }

    private var illustration: some View {
        let usesLargeIllustration = config.showsExitIYSOAnimation
        let illustrationSize: CGFloat = usesLargeIllustration ? 200 : 140

        return ZStack {
            if !usesLargeIllustration {
                Circle()
                    .fill(Color(white: 1, opacity: 0.05))
                    .frame(width: illustrationSize, height: illustrationSize)
            }

            if config.showsLensAttachAnimation {
                lensConnectionBackgroundOverlay
                LensAttachAnimationView(isConnected: $isModeIndicatorActive)
                lensConnectionForegroundOverlay
            } else if config.showsLensReattachAnimation {
                LensAttachAnimationView(loopStyle: .detachThenReattach, isConnected: $isModeIndicatorActive)
            } else if config.showsIYSOShootingModeAnimation {
                IYSOShootingModeAnimationView()
            } else if config.showsExitIYSOAnimation {
                ExitIYSOModeAnimationView(isMemoryUnlocked: $isModeIndicatorActive)
            } else {
                Image(systemName: config.illustrationSystemName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(Color(white: 0.7))
            }
        }
        .frame(width: illustrationSize, height: illustrationSize)
        .onChange(of: config.showsLensAttachAnimation) { showsAnimation in
            if !showsAnimation {
                isModeIndicatorActive = false
            }
        }
        .onChange(of: config.showsLensReattachAnimation) { showsAnimation in
            if !showsAnimation {
                isModeIndicatorActive = false
            }
        }
    }

    @ViewBuilder
    private var lensConnectionBackgroundOverlay: some View {
        switch lensConnectionState {
        case .connected:
            Circle()
                .stroke(Color(red: 0, green: 0.85, blue: 0.4).opacity(0.38), lineWidth: 2)
                .frame(width: 146, height: 146)
                .transition(.opacity.combined(with: .scale))
        case .failed:
            Circle()
                .stroke(Color.red.opacity(0.33), lineWidth: 2)
                .frame(width: 146, height: 146)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var lensConnectionForegroundOverlay: some View {
        switch lensConnectionState {
        case .idle:
            EmptyView()
        case .connecting:
            ProgressView()
                .tint(Color(red: 0.18, green: 0.55, blue: 1.0))
                .scaleEffect(1.05)
        case .connected:
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color(red: 0, green: 0.85, blue: 0.4))
            .transition(.opacity.combined(with: .scale))
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.red)
        }
    }
}
