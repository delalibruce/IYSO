import SwiftUI

// MARK: - Layout (matches LensAttachAnimationView lens + phone)

private enum IYSOShootingLayout {
    static let phoneWidth: CGFloat = 58
    static let phoneHeight: CGFloat = 118
    static let lensDiameter: CGFloat = 40
    static let lensHorizontalNudge: CGFloat = 4
    static let lensVerticalNudge: CGFloat = 0
    /// Lens center on the phone’s top-left corner (~¼ overlapping), mirrored from lens-attach page.
    static let cornerAnchorOffset = CGSize(
        width: -(lensDiameter / 2 + lensHorizontalNudge) + 8,
        height: -lensDiameter / 2 + lensVerticalNudge + 8
    )

    static let distractionIconSize: CGFloat = 9
    static let distractionDotSize: CGFloat = 5
}

// MARK: - Motion (~4.8s loop)

private enum IYSOShootingMotion {
    static let introHold: TimeInterval = 0.45
    static let flashIn: TimeInterval = 0.22
    static let flashPeakHold: TimeInterval = 0.2
    static let flashOut: TimeInterval = 0.52
    static let rippleExpand: TimeInterval = 0.72
    static let distractionsStartHold: TimeInterval = 0.28
    static let distractionsClear: TimeInterval = 0.86
    static let quietHold: TimeInterval = 0.95
    static let resetPause: TimeInterval = 0.38

    static let distractionDriftY: CGFloat = -14
    static let distractionSpreadEnd: CGFloat = 1.14
    static let distractionsVisibleOpacity: Double = 0.55
    static let rippleEndScale: CGFloat = 1.55
}

// MARK: - Palette

private enum IYSOShootingPalette {
    static let phoneFill = Color(white: 0.11)
    static let phoneStroke = Color(white: 0.20)
    static let backSheen = Color(white: 0.13)
    static let lensFill = Color.black
    static let lensStroke = Color(white: 0.28)
    static let emberGlow = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
    static let flashCore = Color(white: 0.96)
    static let flashWarm = Color(red: 0xff / 255, green: 0xf0 / 255, blue: 0xe2 / 255)
    static let distractionFill = Color(white: 0.34)
    static let distractionMuted = Color(white: 0.24)
    static let notificationFill = Color(white: 0.38)
    static let shieldTint = Color(white: 0.9)
}

// MARK: - View

/// Looping clip: distractions fade away, then capture flash on lens-attached iPhone back.
struct IYSOShootingModeAnimationView: View {
    @State private var flashOpacity: Double = 0
    @State private var flashCoreScale: CGFloat = 0.6
    @State private var rippleOpacity: Double = 0
    @State private var rippleScale: CGFloat = 0.85
    @State private var distractionsOpacity: Double = IYSOShootingMotion.distractionsVisibleOpacity
    @State private var distractionsDriftY: CGFloat = 0
    @State private var distractionsSpread: CGFloat = 1
    @State private var shieldOpacity: Double = 0
    @State private var shieldScale: CGFloat = 0.92
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            distractionsLayer
                .opacity(distractionsOpacity)
                .offset(y: distractionsDriftY)
                .scaleEffect(distractionsSpread)

            phoneScene
        }
        .frame(width: 96, height: 148)
        .onAppear { startLoop() }
        .onDisappear {
            loopTask?.cancel()
            loopTask = nil
        }
    }

    // MARK: - Phone back + lens

    private var phoneScene: some View {
        phoneBack
            .frame(width: IYSOShootingLayout.phoneWidth, height: IYSOShootingLayout.phoneHeight)
            .overlay(alignment: .topLeading) {
                lensWithFlash
                    .offset(IYSOShootingLayout.cornerAnchorOffset)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                shieldIndicator
                    .padding(.trailing, 6)
                    .padding(.bottom, 7)
                    .allowsHitTesting(false)
            }
    }

    private var phoneBack: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(IYSOShootingPalette.phoneFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(IYSOShootingPalette.phoneStroke, lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                IYSOShootingPalette.backSheen.opacity(0.5),
                                Color.clear,
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
    }

    private var lensWithFlash: some View {
        ZStack {
            attachedLens
            captureFlash
        }
    }

    private var attachedLens: some View {
        Circle()
            .fill(IYSOShootingPalette.lensFill)
            .frame(width: IYSOShootingLayout.lensDiameter, height: IYSOShootingLayout.lensDiameter)
            .overlay(
                Circle()
                    .strokeBorder(IYSOShootingPalette.lensStroke.opacity(0.45), lineWidth: 1.75)
            )
    }

    // MARK: - Capture flash + ripple

    private var captureFlash: some View {
        ZStack {
            Circle()
                .stroke(IYSOShootingPalette.emberGlow.opacity(0.35), lineWidth: 1)
                .frame(width: 34, height: 34)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            IYSOShootingPalette.emberGlow.opacity(0.4),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 44, height: 44)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity * 0.85)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            IYSOShootingPalette.flashWarm.opacity(0.95),
                            IYSOShootingPalette.flashCore.opacity(0.5),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .frame(width: 22, height: 22)
                .scaleEffect(flashCoreScale)
                .opacity(flashOpacity)
                .blur(radius: 0.5)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Distractions around phone

    private var distractionsLayer: some View {
        ZStack {
            distractionApp
                .offset(x: -44, y: -18)
            distractionNotification
                .offset(x: -38, y: 8)
            distractionApp
                .offset(x: 44, y: -8)
                .opacity(0.85)
            distractionNotification
                .offset(x: 40, y: 22)
                .scaleEffect(0.9)
            distractionApp
                .offset(x: -8, y: 52)
                .opacity(0.75)
        }
    }

    private var distractionApp: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(IYSOShootingPalette.distractionFill)
            .frame(
                width: IYSOShootingLayout.distractionIconSize,
                height: IYSOShootingLayout.distractionIconSize
            )
    }

    private var distractionNotification: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(IYSOShootingPalette.notificationFill)
                .frame(width: 14, height: 5)
            Circle()
                .fill(IYSOShootingPalette.distractionMuted)
                .frame(
                    width: IYSOShootingLayout.distractionDotSize,
                    height: IYSOShootingLayout.distractionDotSize
                )
        }
    }

    private var shieldIndicator: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(IYSOShootingPalette.shieldTint)
            .opacity(shieldOpacity)
            .scaleEffect(shieldScale)
            .shadow(color: IYSOShootingPalette.shieldTint.opacity(0.2), radius: 2, y: 1)
    }

    // MARK: - Loop

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                resetFrame()

                try? await Task.sleep(for: .seconds(
                    IYSOShootingMotion.resetPause
                        + IYSOShootingMotion.introHold
                        + IYSOShootingMotion.distractionsStartHold
                ))
                guard !Task.isCancelled else { break }

                withAnimation(.easeInOut(duration: IYSOShootingMotion.distractionsClear)) {
                    distractionsOpacity = 0
                    distractionsDriftY = IYSOShootingMotion.distractionDriftY
                    distractionsSpread = IYSOShootingMotion.distractionSpreadEnd
                    shieldOpacity = 0.72
                    shieldScale = 1
                }

                try? await Task.sleep(for: .seconds(IYSOShootingMotion.distractionsClear + 0.08))
                guard !Task.isCancelled else { break }

                withAnimation(.easeOut(duration: IYSOShootingMotion.flashIn)) {
                    flashOpacity = 1
                    flashCoreScale = 1
                }
                withAnimation(.easeOut(duration: IYSOShootingMotion.rippleExpand)) {
                    rippleOpacity = 0.7
                    rippleScale = IYSOShootingMotion.rippleEndScale
                }

                try? await Task.sleep(for: .seconds(
                    IYSOShootingMotion.flashIn + IYSOShootingMotion.flashPeakHold
                ))
                guard !Task.isCancelled else { break }

                withAnimation(.easeOut(duration: IYSOShootingMotion.flashOut)) {
                    flashOpacity = 0
                    flashCoreScale = 0.75
                }
                withAnimation(.easeOut(duration: IYSOShootingMotion.flashOut * 1.1)) {
                    rippleOpacity = 0
                }

                try? await Task.sleep(for: .seconds(
                    IYSOShootingMotion.flashOut + IYSOShootingMotion.quietHold
                ))
            }
        }
    }

    private func resetFrame() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            flashOpacity = 0
            flashCoreScale = 0.6
            rippleOpacity = 0
            rippleScale = 0.85
            distractionsOpacity = IYSOShootingMotion.distractionsVisibleOpacity
            distractionsDriftY = 0
            distractionsSpread = 1
            shieldOpacity = 0
            shieldScale = 0.92
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        IYSOShootingModeAnimationView()
    }
}
