import SwiftUI

// MARK: - Configuration (easy to tweak or remove later)

enum IYSOLoadingConfig {
    /// Shown under the wordmark while the launch screen is visible.
    static let caption = "pronounced \"eye-so\"..."

    /// Set to `false` while tuning orb motion only.
    static let autoDismisses = true

    /// How long the branded loading screen stays up before fading out.
    static let displayDuration: TimeInterval = 1.6

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

// MARK: - Center orb palette

private enum LoadingOrbPalette {
    static let warmAccent = Color(red: 0xA5 / 255, green: 0x44 / 255, blue: 0x1D / 255)
    static let coolAccent = Color(red: 0x8E / 255, green: 0xE6 / 255, blue: 0xF6 / 255)
    static let neutralWarmOuter = Color(red: 0x72 / 255, green: 0x52 / 255, blue: 0x36 / 255)
    static let neutralWarmCore = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
    static let coreDark = Color(red: 0x12 / 255, green: 0x0f / 255, blue: 0x0c / 255)
}

// MARK: - Center orb motion (glow layers only)

private enum LoadingOrbAnimation {
    static let cycleDuration: TimeInterval = 3.6
    static let scaleAtRest: CGFloat = 0.96
    static let scaleAtPeak: CGFloat = 1.04
    static let floatOffsetAtRest: CGFloat = 5
    static let floatOffsetAtPeak: CGFloat = -6
    static let glowStrengthAtRest: CGFloat = 0.52
    static let glowStrengthAtPeak: CGFloat = 1.1
    static let blurAtRest: CGFloat = 36
    static let blurAtPeak: CGFloat = 54
    static let driftAtRest = CGSize(width: -14, height: 10)
    static let driftAtPeak = CGSize(width: 16, height: -14)
    static let warmBiasAtRest: CGFloat = 0.72
    static let warmBiasAtPeak: CGFloat = 1.35
    static let coolBiasAtRest: CGFloat = 0.45
    static let coolBiasAtPeak: CGFloat = 1.05
}

// MARK: - Loading screen

struct IYSOLoadingScreen: View {
    private let wordmarkFontSize: CGFloat = 72
    private let wordmarkLetterSpacingPercent: CGFloat = 8

    @State private var contentOpacity: Double = 0
    @State private var orbScale: CGFloat = LoadingOrbAnimation.scaleAtRest
    @State private var orbFloatOffset: CGFloat = LoadingOrbAnimation.floatOffsetAtRest
    @State private var orbGlowStrength: CGFloat = LoadingOrbAnimation.glowStrengthAtRest
    @State private var orbBlur: CGFloat = LoadingOrbAnimation.blurAtRest
    @State private var orbDrift: CGSize = LoadingOrbAnimation.driftAtRest
    @State private var warmBias: CGFloat = LoadingOrbAnimation.warmBiasAtRest
    @State private var coolBias: CGFloat = LoadingOrbAnimation.coolBiasAtRest
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
                    LoadingOrbPalette.neutralWarmOuter.opacity(0.06 + 0.2 * orbGlowStrength),
                    IYSOLaunchPalette.warmGlow.opacity(0.05 + 0.16 * orbGlowStrength),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
        }
    }

    private var wordmarkCluster: some View {
        ZStack {
            centerOrb

            Text("IYSO")
                .font(IYSOFont.bootzy(size: wordmarkFontSize))
                .tracking(IYSOFont.tracking(percentOfFontSize: wordmarkLetterSpacingPercent, fontSize: wordmarkFontSize))
                .foregroundStyle(IYSOLaunchPalette.title)
                .fixedSize()
        }
    }

    private var centerOrb: some View {
        ZStack {
            // Brown neutral atmosphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.neutralWarmOuter.opacity(0.38 * orbGlowStrength),
                            LoadingOrbPalette.neutralWarmCore.opacity(0.24 * orbGlowStrength),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.5, y: 0.55),
                        startRadius: 10,
                        endRadius: 98
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: orbBlur)
                .offset(x: orbDrift.width * 0.25, y: orbDrift.height * 0.2)

            // Warm brand bloom — primary read
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.warmAccent.opacity(0.5 * warmBias * orbGlowStrength),
                            LoadingOrbPalette.warmAccent.opacity(0.28 * warmBias),
                            LoadingOrbPalette.neutralWarmOuter.opacity(0.16 * orbGlowStrength),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.44, y: 0.58),
                        startRadius: 2,
                        endRadius: 96
                    )
                )
                .frame(width: 196, height: 196)
                .blur(radius: orbBlur * 0.88)
                .offset(x: -orbDrift.width * 0.15, y: orbDrift.height * 0.12)

            // Tight warm ember core (extra copper punch)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.warmAccent.opacity(0.55 * warmBias),
                            LoadingOrbPalette.warmAccent.opacity(0.22 * warmBias),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.48, y: 0.56),
                        startRadius: 0,
                        endRadius: 58
                    )
                )
                .frame(width: 118, height: 118)
                .blur(radius: orbBlur * 0.55)

            // Cool cyan wash — softer, smaller
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.coolAccent.opacity(0.18 * coolBias * orbGlowStrength),
                            LoadingOrbPalette.coolAccent.opacity(0.07 * coolBias),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.62, y: 0.34),
                        startRadius: 2,
                        endRadius: 82
                    )
                )
                .frame(width: 168, height: 168)
                .blur(radius: orbBlur * 0.85)
                .offset(x: orbDrift.width * 0.55, y: orbDrift.height * 0.5)

            // Mid body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.neutralWarmCore.opacity(0.4 * orbGlowStrength),
                            LoadingOrbPalette.warmAccent.opacity(0.36 * warmBias),
                            LoadingOrbPalette.coolAccent.opacity(0.1 * coolBias),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 72
                    )
                )
                .frame(width: 148, height: 148)
                .blur(radius: orbBlur * 0.62)

            // Soft core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            LoadingOrbPalette.coreDark.opacity(0.82),
                            LoadingOrbPalette.warmAccent.opacity(0.58 * warmBias * orbGlowStrength),
                            LoadingOrbPalette.coolAccent.opacity(0.18 * coolBias * orbGlowStrength),
                            LoadingOrbPalette.neutralWarmOuter.opacity(0.26 * orbGlowStrength),
                            Color.clear,
                        ],
                        center: UnitPoint(x: 0.5, y: 0.52),
                        startRadius: 0,
                        endRadius: 58
                    )
                )
                .frame(width: 118, height: 118)
                .blur(radius: orbBlur * 0.42)
        }
        .compositingGroup()
        .scaleEffect(orbScale)
        .offset(x: orbDrift.width, y: orbFloatOffset + orbDrift.height)
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

        if IYSOLoadingConfig.autoDismisses {
            withAnimation(.easeInOut(duration: IYSOLoadingConfig.progressAnimationDuration)) {
                progress = 1
            }
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
            orbBlur = LoadingOrbAnimation.blurAtPeak
            orbDrift = LoadingOrbAnimation.driftAtPeak
            warmBias = LoadingOrbAnimation.warmBiasAtPeak
            coolBias = LoadingOrbAnimation.coolBiasAtPeak
        }
    }
}

#Preview {
    IYSOLoadingScreen()
}
