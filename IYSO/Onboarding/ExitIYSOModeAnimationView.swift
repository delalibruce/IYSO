import SwiftUI

private enum ExitIYSOButtonAnimationLayout {
    static let sceneWidth: CGFloat = 200
    static let sceneHeight: CGFloat = 200
    static let buttonMagnification: CGFloat = 1.5
    static let glowStartScale: CGFloat = 1
    static let glowEndScale: CGFloat = 1.18
    static let glowEdgeInset: CGFloat = 2
}

private enum ExitIYSOButtonAnimationMotion {
    static let resetPause: TimeInterval = 0.35
    static let holdBeforeTap: TimeInterval = 0.95
    static let tapDown: TimeInterval = 0.22
    static let tapRelease: TimeInterval = 0.18
    static let holdAfterTap: TimeInterval = 1.15
    static let glowPulse: TimeInterval = 0.95
}

/// Looping clip: only the Exit IYSO Mode button press.
struct ExitIYSOModeAnimationView: View {
    @Binding var isMemoryUnlocked: Bool
    @State private var isButtonPressed = false
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = ExitIYSOButtonAnimationLayout.glowStartScale
    @State private var buttonSize: CGSize = .zero
    @State private var loopTask: Task<Void, Never>?

    init(isMemoryUnlocked: Binding<Bool> = .constant(false)) {
        _isMemoryUnlocked = isMemoryUnlocked
    }

    var body: some View {
        ExitIYSOModeButton(
                isPressed: isButtonPressed,
                magnification: ExitIYSOButtonAnimationLayout.buttonMagnification
            )
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { buttonSize = proxy.size }
                        .onChange(of: proxy.size) { buttonSize = $0 }
                }
            }
            .overlay {
                ZStack {
                    Capsule()
                        .stroke(
                            Color(red: 0x8E / 255, green: 0x63 / 255, blue: 0x43 / 255).opacity(0.78),
                            lineWidth: 1.1
                        )

                    Capsule()
                        .stroke(
                            Color(red: 0x8E / 255, green: 0x63 / 255, blue: 0x43 / 255).opacity(0.5),
                            lineWidth: 4.2
                        )
                        .blur(radius: 8.5)
                }
                .background(
                    Capsule()
                        .fill(Color(red: 0x8E / 255, green: 0x63 / 255, blue: 0x43 / 255).opacity(0.2))
                        .blur(radius: 2)
                )
                .frame(width: glowBaseSize.width, height: glowBaseSize.height)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .allowsHitTesting(false)
            }
            .frame(
                width: ExitIYSOButtonAnimationLayout.sceneWidth,
                height: ExitIYSOButtonAnimationLayout.sceneHeight
            )
        .onAppear { startLoop() }
        .onDisappear {
            loopTask?.cancel()
            loopTask = nil
        }
    }

    // MARK: - Loop

    private var glowBaseSize: CGSize {
        let fallback = CGSize(width: 176, height: 52)
        let source = buttonSize == .zero ? fallback : buttonSize
        return CGSize(
            width: source.width + ExitIYSOButtonAnimationLayout.glowEdgeInset * 2,
            height: source.height + ExitIYSOButtonAnimationLayout.glowEdgeInset * 2
        )
    }

    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                resetFrame()

                try? await Task.sleep(for: .seconds(ExitIYSOButtonAnimationMotion.resetPause))
                guard !Task.isCancelled else { break }

                try? await Task.sleep(for: .seconds(ExitIYSOButtonAnimationMotion.holdBeforeTap))
                guard !Task.isCancelled else { break }

                withAnimation(.easeOut(duration: ExitIYSOButtonAnimationMotion.tapDown)) {
                    isButtonPressed = true
                }

                try? await Task.sleep(for: .seconds(ExitIYSOButtonAnimationMotion.tapDown))
                guard !Task.isCancelled else { break }

                withAnimation(.easeOut(duration: ExitIYSOButtonAnimationMotion.tapRelease)) {
                    isButtonPressed = false
                }

                try? await Task.sleep(for: .seconds(ExitIYSOButtonAnimationMotion.tapRelease))
                guard !Task.isCancelled else { break }

                var glowReset = Transaction()
                glowReset.disablesAnimations = true
                withTransaction(glowReset) {
                    glowOpacity = 0.45
                    glowScale = ExitIYSOButtonAnimationLayout.glowStartScale
                }
                withAnimation(.easeOut(duration: ExitIYSOButtonAnimationMotion.glowPulse)) {
                    glowOpacity = 0
                    glowScale = ExitIYSOButtonAnimationLayout.glowEndScale
                }

                isMemoryUnlocked = true

                try? await Task.sleep(for: .seconds(ExitIYSOButtonAnimationMotion.holdAfterTap))
            }
        }
    }

    private func resetFrame() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isButtonPressed = false
            isMemoryUnlocked = false
            glowOpacity = 0
            glowScale = ExitIYSOButtonAnimationLayout.glowStartScale
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ExitIYSOModeAnimationView(isMemoryUnlocked: .constant(false))
    }
}
