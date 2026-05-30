import SwiftUI

// MARK: - Configuration (easy to tweak or remove later)

enum IYSOLoadingConfig {
    /// Shown under the wordmark while the launch screen is visible.
    static let caption = "pronounced \"eye-so\"..."

    /// Set to `false` while tuning orb motion only.
    static let autoDismisses = true

    /// How long the branded loading screen stays up before fading out.
    static let displayDuration: TimeInterval = 1.6

    /// Extra dwell time for the user's first-ever app open.
    static let firstLaunchDisplayDuration: TimeInterval = 4.0

    /// Show launch loading again only after this much idle time.
    static let relaunchAfterIdleInterval: TimeInterval = 20 * 60
}

// MARK: - Loading screen typography & chrome

private enum IYSOLoadingChromePalette {
    static let warmGlowCore = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
    static let title = Color(white: 0.92)
    static let caption = Color(white: 0.48)
    static let indicator = Color(red: 0x00 / 255, green: 0xdf / 255, blue: 0x4f / 255)
    static let progressTrack = Color(white: 1, opacity: 0.12)
    static let progressFill = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
}

// MARK: - Loading screen

struct IYSOLoadingScreen: View {
    private let wordmarkFontSize: CGFloat = 72
    private let wordmarkLetterSpacingPercent: CGFloat = 8
    private let displayDuration: TimeInterval
    private let usesSlowFirstLaunchProgress: Bool

    @State private var contentOpacity: Double = 0
    @State private var indicatorLit = false
    @State private var progress: CGFloat = 0

    init(
        displayDuration: TimeInterval = IYSOLoadingConfig.displayDuration,
        usesSlowFirstLaunchProgress: Bool = false
    ) {
        self.displayDuration = displayDuration
        self.usesSlowFirstLaunchProgress = usesSlowFirstLaunchProgress
    }

    var body: some View {
        ZStack {
            IYSOLaunchBackground()

            VStack(spacing: 28) {
                wordmarkCluster

                captionRow

                progressBar
                    .frame(maxWidth: 280)
            }
            .opacity(contentOpacity)
        }
        .ignoresSafeArea()
        .onAppear(perform: startAnimations)
    }

    // MARK: - Layers

    private var wordmarkCluster: some View {
        Text("IYSO")
            .font(IYSOFont.bootzy(size: wordmarkFontSize))
            .tracking(IYSOFont.tracking(percentOfFontSize: wordmarkLetterSpacingPercent, fontSize: wordmarkFontSize))
            .foregroundStyle(IYSOLoadingChromePalette.title)
            .fixedSize()
    }

    private var captionRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(IYSOLoadingChromePalette.indicator)
                .frame(width: 6, height: 6)
                .opacity(indicatorLit ? 0.95 : 0.28)
                .shadow(color: IYSOLoadingChromePalette.indicator.opacity(indicatorLit ? 0.55 : 0), radius: 4)

            Text(IYSOLoadingConfig.caption)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(IYSOLoadingChromePalette.caption)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(IYSOLoadingChromePalette.progressTrack)

                Capsule()
                    .fill(IYSOLoadingChromePalette.progressFill)
                    .frame(width: max(geometry.size.width * progress, 0))
            }
        }
        .frame(height: 2)
    }

    // MARK: - Animation

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.9)) {
            contentOpacity = 1
        }

        if IYSOLoadingConfig.autoDismisses {
            let progressAnimation: Animation = usesSlowFirstLaunchProgress
                ? .linear(duration: displayDuration)
                : .easeInOut(duration: displayDuration)
            withAnimation(progressAnimation) {
                progress = 1
            }
        }

        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            indicatorLit = true
        }
    }
}

#Preview {
    IYSOLoadingScreen()
}
