import SwiftUI

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
    /// When false, only headline and body are shown (no illustration area).
    let showsIllustration: Bool
}

extension ExplainerConfig {
    static let howItWorks = ExplainerConfig(
        headline: "Attach your lens to get started.",
        body: "",
        illustrationSystemName: "camera.aperture",
        dotIndex: 1, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: nil,
        showsLensAttachAnimation: true,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsIllustration: true
    )
    static let twoModes = ExplainerConfig(
        headline: "IYSO has two modes.",
        body: "",
        illustrationSystemName: "square.grid.2x2",
        dotIndex: 2, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: nil,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsIllustration: false
    )
    static let iysoMode = ExplainerConfig(
        headline: "1. IYSO mode",
        body: "when you're in IYSO mode, apps you've selected as distractions are blocked so you can stay in the moment. It's just you, the camera, and the messy shot.",
        illustrationSystemName: "camera.fill",
        dotIndex: 3, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: .iyso,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: true,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false,
        showsIllustration: true
    )
    static let memoryMode = ExplainerConfig(
        headline: "2. Memory Mode",
        body: "when you're done capturing memories, tap \"Exit IYSO Mode\" to unlock your memory card and view your photos.",
        illustrationSystemName: "photo.stack.fill",
        dotIndex: 4, dotTotal: 4,
        ctaLabel: "let's finish setting up.",
        modeBadge: .memory,
        showsLensAttachAnimation: false,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: true,
        drivesModeBadgeWithExitIYSOAnimation: true,
        showsIllustration: true
    )
}

struct ExplainerFlowView: View {
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var page = 0
    @State private var suppressNextPageChangeHaptic = false

    private static let configs: [ExplainerConfig] = [.howItWorks, .twoModes, .iysoMode, .memoryMode]

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
                        ExplainerScreen(config: Self.configs[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 24) {
                    OnboardingProgressDots(total: currentConfig.dotTotal, current: page + 1)

                    OnboardingContinueButton(
                        title: currentConfig.ctaLabel.lowercased(),
                        action: advanceFromButton
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
        .onChange(of: page) { _ in
            if suppressNextPageChangeHaptic {
                suppressNextPageChangeHaptic = false
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func advanceFromButton() {
        if page < Self.configs.count - 1 {
            suppressNextPageChangeHaptic = true
            withAnimation(.easeInOut(duration: 0.28)) {
                page += 1
            }
        } else {
            onComplete()
        }
    }

    private func handleBack() {
        if page > 0 {
            suppressNextPageChangeHaptic = true
            withAnimation(.easeInOut(duration: 0.28)) {
                page -= 1
            }
        } else {
            onBack()
        }
    }
}

private enum ExplainerTextLayout {
    static let headlineToBodySpacing: CGFloat = 10
}

struct ExplainerScreen: View {
    let config: ExplainerConfig

    @State private var isModeIndicatorActive = false

    var body: some View {
        // Memory mode needs the text slightly closer to the larger exit-IYSO animation.
        let illustrationToTextSpacing: CGFloat = config.showsExitIYSOAnimation ? 40 : 48
        let contentVerticalOffset: CGFloat = config.showsExitIYSOAnimation ? -12 : 0

        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: config.showsIllustration ? illustrationToTextSpacing : 0) {
                if config.showsIllustration {
                    illustration
                }

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

                        if !config.headline.isEmpty {
                            Text(config.headline)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !config.body.isEmpty {
                        Text(config.body)
                            .font(.system(size: config.headline.isEmpty ? 28 : 17, weight: config.headline.isEmpty ? .bold : .regular))
                            .foregroundColor(config.headline.isEmpty ? .white : Color(white: 0.55))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                LensAttachAnimationView(isConnected: $isModeIndicatorActive)
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
    }
}
