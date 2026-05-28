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
    /// Replaces the SF Symbol with the IYSO shooting-mode instructional animation.
    let showsIYSOShootingModeAnimation: Bool
    /// Replaces the SF Symbol with the exit-IYSO → memory-card instructional animation.
    let showsExitIYSOAnimation: Bool
    /// When true, the mode badge dot is activated by the exit-IYSO animation tap.
    let drivesModeBadgeWithExitIYSOAnimation: Bool
}

extension ExplainerConfig {
    static let enterIYSO = ExplainerConfig(
        headline: "Before you start shooting",
        body: "Switch to IYSO Mode when you're ready. Your chosen apps get shielded so you can stay in the moment.",
        illustrationSystemName: "shield.lefthalf.filled",
        dotIndex: 1, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: .iyso,
        showsIYSOShootingModeAnimation: true,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false
    )
    static let iysoMode = ExplainerConfig(
        headline: "IYSO Mode is for shooting",
        body: "Notifications off. Outside apps locked. Just you and the shot.",
        illustrationSystemName: "camera.fill",
        dotIndex: 2, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: nil,
        showsIYSOShootingModeAnimation: true,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false
    )
    static let memoryMode = ExplainerConfig(
        headline: "Done shooting?",
        body: "Tap “Exit IYSO Mode” to unlock your memory card to view photos.",
        illustrationSystemName: "photo.stack.fill",
        dotIndex: 3, dotTotal: 4,
        ctaLabel: "Next",
        modeBadge: .memory,
        showsIYSOShootingModeAnimation: false,
        showsExitIYSOAnimation: true,
        drivesModeBadgeWithExitIYSOAnimation: true
    )
    static let shootAgain = ExplainerConfig(
        headline: "Ready to shoot again?",
        body: "Tap the camera toggle to enter IYSO Mode. Your apps will be shielded again.",
        illustrationSystemName: "camera.fill",
        dotIndex: 4, dotTotal: 4,
        ctaLabel: "Got it",
        modeBadge: nil,
        showsIYSOShootingModeAnimation: true,
        showsExitIYSOAnimation: false,
        drivesModeBadgeWithExitIYSOAnimation: false
    )
}

struct ExplainerFlowView: View {
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var page = 0

    private static let configs: [ExplainerConfig] = [.enterIYSO, .iysoMode, .memoryMode, .shootAgain]

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
    }

    private func advanceFromButton() {
        if page < Self.configs.count - 1 {
            withAnimation(.easeInOut(duration: 0.28)) {
                page += 1
            }
        } else {
            onComplete()
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
}

private enum ExplainerTextLayout {
    static let headlineToBodySpacing: CGFloat = 10
}

struct ExplainerScreen: View {
    let config: ExplainerConfig

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
                                isIndicatorActive: config.drivesModeBadgeWithExitIYSOAnimation
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

            if config.showsIYSOShootingModeAnimation {
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
    }
}
