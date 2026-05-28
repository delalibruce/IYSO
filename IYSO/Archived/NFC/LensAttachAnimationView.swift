import SwiftUI

// MARK: - Layout

private enum LensAttachLayout {
    static let phoneWidth: CGFloat = 58
    static let phoneHeight: CGFloat = 118
    static let lensDiameter: CGFloat = 40
    static let lensHorizontalNudge: CGFloat = 4
    static let lensVerticalNudge: CGFloat = 0
    /// Primary camera lens dot (turns green on attach).
    static let primaryCameraLensOffset = CGSize(width: -5, height: 0)
    /// Nudges lens so its center sits on the phone’s top-right corner (~¼ overlapping).
    static let cornerAnchorOffset = CGSize(
        width: lensDiameter / 2 + lensHorizontalNudge,
        height: -lensDiameter / 2 + lensVerticalNudge
    )
}

// MARK: - Motion timing

private enum LensAttachMotion {
    static let slideDuration: TimeInterval = 1.15
    static let settleDuration: TimeInterval = 0.16
    static let attachedHold: TimeInterval = 0.85
    static let resetPause: TimeInterval = 0.4
    static let removalDuration: TimeInterval = 0.9
    static let removedHold: TimeInterval = 0.55
    static let initiallyAttachedHold: TimeInterval = 0.45

    static let detachedOffset = CGSize(width: 24, height: -28)
    static let attachedOffset = CGSize(width: 0, height: 0)

    static let detachedScale: CGFloat = 0.93
    static let attachedScale: CGFloat = 1
    static let settleScale: CGFloat = 1.025
}

// MARK: - Palette

private enum LensAttachPalette {
    static let phoneFill = Color(white: 0.11)
    static let phoneStroke = Color(white: 0.20)
    static let screenFill = Color(white: 0.07)
    static let cameraHousing = Color(white: 0.16)
    static let cameraLens = Color(white: 0.28)
    static let lensFill = Color.black
    static let lensStroke = Color(white: 0.28)
    static let warmGlow = Color(red: 0x9a / 255, green: 0x78 / 255, blue: 0x5c / 255)
    static let connected = Color(red: 0x00 / 255, green: 0xdf / 255, blue: 0x4f / 255)
}

// MARK: - View

/// Looping instructional clip: circular lens slides onto the top-right corner of a simplified iPhone.
struct LensAttachAnimationView: View {
    enum LoopStyle {
        case attachOnly
        case detachThenReattach
    }

    @Binding var isConnected: Bool
    private let loopStyle: LoopStyle

    @State private var lensTravel: CGSize = LensAttachMotion.detachedOffset
    @State private var lensScale: CGFloat = LensAttachMotion.detachedScale
    @State private var attachGlowOpacity: Double = 0
    @State private var indicatorOpacity: Double = 0
    @State private var loopTask: Task<Void, Never>?

    init(
        loopStyle: LoopStyle = .attachOnly,
        isConnected: Binding<Bool> = .constant(false)
    ) {
        self.loopStyle = loopStyle
        _isConnected = isConnected
    }

    private var lensOffset: CGSize {
        CGSize(
            width: LensAttachLayout.cornerAnchorOffset.width + lensTravel.width,
            height: LensAttachLayout.cornerAnchorOffset.height + lensTravel.height
        )
    }

    var body: some View {
        phoneIllustration
            .frame(width: 96, height: 148)
            .onAppear { startLoop() }
            .onDisappear {
                loopTask?.cancel()
                loopTask = nil
                isConnected = false
            }
    }

    // MARK: - Phone + lens

    private var phoneIllustration: some View {
        phoneBody
            .frame(width: LensAttachLayout.phoneWidth, height: LensAttachLayout.phoneHeight)
            .background(alignment: .topTrailing) {
                lensAssembly
                    .offset(lensOffset)
                    .scaleEffect(lensScale)
                    .allowsHitTesting(false)
            }
    }

    private var phoneBody: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LensAttachPalette.phoneFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LensAttachPalette.phoneStroke, lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LensAttachPalette.screenFill)
                .padding(.horizontal, 5)
                .padding(.vertical, 14)

            cameraModule
                .padding(.top, 10)
        }
    }

    private var cameraModule: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LensAttachPalette.cameraHousing)
                .frame(width: 26, height: 9)

            Circle()
                .fill(LensAttachPalette.cameraLens)
                .frame(width: 5.5, height: 5.5)
                .offset(x: LensAttachLayout.primaryCameraLensOffset.width)

            Circle()
                .fill(LensAttachPalette.cameraLens.opacity(0.65))
                .frame(width: 4, height: 4)
                .offset(x: 5)

            Circle()
                .fill(LensAttachPalette.connected)
                .frame(width: 5.5, height: 5.5)
                .shadow(color: LensAttachPalette.connected.opacity(0.55), radius: 4)
                .opacity(indicatorOpacity)
                .offset(x: LensAttachLayout.primaryCameraLensOffset.width)
        }
    }

    // MARK: - Lens + circular confirmation glow (behind phone)

    private var lensAssembly: some View {
        ZStack {
            attachGlow
                .opacity(attachGlowOpacity)

            lensClip
        }
    }

    private var lensClip: some View {
        Circle()
            .fill(LensAttachPalette.lensFill)
            .frame(width: LensAttachLayout.lensDiameter, height: LensAttachLayout.lensDiameter)
            .overlay(
                Circle()
                    .strokeBorder(LensAttachPalette.lensStroke.opacity(0.45), lineWidth: 1.75)
            )
    }

    /// Subtle ring-shaped confirmation glow hugging the black lens circle.
    private var attachGlow: some View {
        ZStack {
            Circle()
                .stroke(LensAttachPalette.connected.opacity(0.22), lineWidth: 1.5)
                .frame(
                    width: LensAttachLayout.lensDiameter + 6,
                    height: LensAttachLayout.lensDiameter + 6
                )

            Circle()
                .stroke(LensAttachPalette.connected.opacity(0.1), lineWidth: 3)
                .frame(
                    width: LensAttachLayout.lensDiameter + 10,
                    height: LensAttachLayout.lensDiameter + 10
                )
                .blur(radius: 2)
        }
    }

    // MARK: - Loop

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                if loopStyle == .detachThenReattach {
                    await runDetachThenReattachLoop()
                } else {
                    await runAttachOnlyLoop()
                }
            }
        }
    }

    @MainActor
    private func runAttachOnlyLoop() async {
        resetDetachedFrame()

        try? await Task.sleep(for: .seconds(LensAttachMotion.resetPause))
        guard !Task.isCancelled else { return }

        await animateAttach()
    }

    @MainActor
    private func runDetachThenReattachLoop() async {
        resetAttachedFrame()

        try? await Task.sleep(for: .seconds(LensAttachMotion.initiallyAttachedHold))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: LensAttachMotion.removalDuration)) {
            lensTravel = LensAttachMotion.detachedOffset
            lensScale = LensAttachMotion.detachedScale
            attachGlowOpacity = 0
            indicatorOpacity = 0
            isConnected = false
        }

        try? await Task.sleep(for: .seconds(LensAttachMotion.removalDuration))
        guard !Task.isCancelled else { return }

        try? await Task.sleep(for: .seconds(LensAttachMotion.removedHold))
        guard !Task.isCancelled else { return }

        await animateAttach()
    }

    @MainActor
    private func animateAttach() async {
        withAnimation(.easeInOut(duration: LensAttachMotion.slideDuration)) {
            lensTravel = LensAttachMotion.attachedOffset
            lensScale = LensAttachMotion.attachedScale
        }

        try? await Task.sleep(for: .seconds(LensAttachMotion.slideDuration))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: LensAttachMotion.settleDuration)) {
            lensScale = LensAttachMotion.settleScale
        }
        withAnimation(.easeOut(duration: LensAttachMotion.settleDuration * 1.2)) {
            attachGlowOpacity = 1
            indicatorOpacity = 1
            isConnected = true
        }

        try? await Task.sleep(for: .seconds(LensAttachMotion.settleDuration))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: LensAttachMotion.settleDuration)) {
            lensScale = LensAttachMotion.attachedScale
        }

        try? await Task.sleep(for: .seconds(LensAttachMotion.attachedHold))
    }

    private func resetDetachedFrame() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lensTravel = LensAttachMotion.detachedOffset
            lensScale = LensAttachMotion.detachedScale
            attachGlowOpacity = 0
            indicatorOpacity = 0
            isConnected = false
        }
    }

    private func resetAttachedFrame() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lensTravel = LensAttachMotion.attachedOffset
            lensScale = LensAttachMotion.attachedScale
            attachGlowOpacity = 1
            indicatorOpacity = 1
            isConnected = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LensAttachAnimationView()
    }
}
