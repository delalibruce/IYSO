import SwiftUI

// MARK: - Configuration (easy to tweak or remove later)

enum IYSOLoadingConfig {
    /// Shown under the wordmark while the launch screen is visible.
    static let caption = "loading memory card..."

    /// How long the branded loading screen stays up before fading out.
    /// TODO: set back to 2.5 after testing.
    static let displayDuration: TimeInterval = 10

    /// Duration of the progress bar fill animation (matches display duration).
    static var progressAnimationDuration: TimeInterval { displayDuration }
}

// MARK: - Brand palette (launch screen only)

private enum IYSOLaunchPalette {
    static let backgroundTop = Color(red: 0x14 / 255, green: 0x11 / 255, blue: 0x0f / 255)
    static let backgroundBottom = Color(red: 0x0a / 255, green: 0x08 / 255, blue: 0x07 / 255)
    static let warmGlow = Color(red: 0x72 / 255, green: 0x52 / 255, blue: 0x36 / 255)
    static let warmGlowCore = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
    static let title = Color(white: 0.92)
    static let caption = Color(white: 0.48)
    static let indicator = Color(red: 0x00 / 255, green: 0xdf / 255, blue: 0x4f / 255)
    static let progressTrack = Color(white: 1, opacity: 0.12)
    static let progressFill = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
}

// MARK: - Center orb motion (glow layers only)

private enum LoadingOrbAnimation {
    static let cycleDuration: TimeInterval = 3.2
    static let scaleAtRest: CGFloat = 1.0
    static let scaleAtPeak: CGFloat = 1.03
    static let floatOffsetAtRest: CGFloat = 0
    static let floatOffsetAtPeak: CGFloat = -4
    static let glowStrengthAtRest: CGFloat = 0.88
    static let glowStrengthAtPeak: CGFloat = 1.0
    static let outerBlurAtRest: CGFloat = 52
    static let outerBlurAtPeak: CGFloat = 58
}

// MARK: - Loading screen

struct IYSOLoadingScreen: View {
    private let wordmarkFontSize: CGFloat = 72
    private let wordmarkLetterSpacingPercent: CGFloat = 8

    @State private var contentOpacity: Double = 0
    @State private var orbScale: CGFloat = LoadingOrbAnimation.scaleAtRest
    @State private var orbFloatOffset: CGFloat = LoadingOrbAnimation.floatOffsetAtRest
    @State private var orbGlowStrength: CGFloat = LoadingOrbAnimation.glowStrengthAtRest
    @State private var orbOuterBlur: CGFloat = LoadingOrbAnimation.outerBlurAtRest
    @State private var indicatorLit = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            background

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

    private var background: some View {
        LinearGradient(
            colors: [
                IYSOLaunchPalette.backgroundTop,
                IYSOLaunchPalette.backgroundBottom,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            RadialGradient(
                colors: [
                    IYSOLaunchPalette.warmGlow.opacity(0.14),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
        }
    }

    private var wordmarkCluster: some View {
        ZStack {
            centerOrb

            Text("iyso")
                .font(IYSOFont.bootzy(size: wordmarkFontSize))
                .tracking(IYSOFont.tracking(percentOfFontSize: wordmarkLetterSpacingPercent, fontSize: wordmarkFontSize))
                .foregroundStyle(IYSOLaunchPalette.title)
                .fixedSize()
        }
    }

    private var centerOrb: some View {
        ZStack {
            Circle()
                .fill(IYSOLaunchPalette.warmGlow.opacity(0.38 * orbGlowStrength))
                .frame(width: 200, height: 200)
                .blur(radius: orbOuterBlur)

            Circle()
                .fill(IYSOLaunchPalette.warmGlowCore.opacity(0.24 * orbGlowStrength))
                .frame(width: 120, height: 120)
                .blur(radius: 32 + (orbOuterBlur - LoadingOrbAnimation.outerBlurAtRest) * 0.35)
        }
        .scaleEffect(orbScale)
        .offset(y: orbFloatOffset)
    }

    private var captionRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(IYSOLaunchPalette.indicator)
                .frame(width: 6, height: 6)
                .opacity(indicatorLit ? 0.95 : 0.28)
                .shadow(color: IYSOLaunchPalette.indicator.opacity(indicatorLit ? 0.55 : 0), radius: 4)

            Text(IYSOLoadingConfig.caption)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(IYSOLaunchPalette.caption)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(IYSOLaunchPalette.progressTrack)

                Capsule()
                    .fill(IYSOLaunchPalette.progressFill)
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

        withAnimation(.easeInOut(duration: IYSOLoadingConfig.progressAnimationDuration)) {
            progress = 1
        }

        startOrbAnimation()

        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            indicatorLit = true
        }
    }

    private func startOrbAnimation() {
        let orbMotion = Animation.easeInOut(duration: LoadingOrbAnimation.cycleDuration)
            .repeatForever(autoreverses: true)

        withAnimation(orbMotion) {
            orbScale = LoadingOrbAnimation.scaleAtPeak
            orbFloatOffset = LoadingOrbAnimation.floatOffsetAtPeak
            orbGlowStrength = LoadingOrbAnimation.glowStrengthAtPeak
            orbOuterBlur = LoadingOrbAnimation.outerBlurAtPeak
        }
    }
}

#Preview {
    IYSOLoadingScreen()
}
