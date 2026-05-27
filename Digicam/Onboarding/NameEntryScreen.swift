import SwiftUI

struct NameEntryScreen: View {
    @Binding var name: String
    /// When false, keyboard focus waits until launch loading has finished.
    var isLaunchLoadingComplete: Bool = true
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool
    @State private var focusTask: Task<Void, Never>?
    @State private var inputRevealedAt: Date?
    @State private var showsInput = false

    private let inputRevealAnimationDuration: TimeInterval = 0.22
    private let inputRevealAnimation: Animation = .easeOut(duration: 0.22)
    private let keyboardFocusDelay: Duration = .milliseconds(40)

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    Text("What's your name?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    TextField("your name", text: $name)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .tint(.white)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if canContinue { onContinue() }
                        }
                        .padding(.vertical, 14)
                        .overlay(
                            Rectangle()
                                .fill(Color(white: 1, opacity: 0.25))
                                .frame(height: 1),
                            alignment: .bottom
                        )
                        .padding(.horizontal, 40)
                        .opacity(showsInput ? 1 : 0)
                        .offset(y: showsInput ? 0 : 14)
                        .allowsHitTesting(showsInput)
                }

                Spacer()

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            inputRevealedAt = Date()
            withAnimation(inputRevealAnimation) {
                showsInput = true
            }
            scheduleKeyboardFocus()
        }
        .onChange(of: isLaunchLoadingComplete) { _ in scheduleKeyboardFocus() }
        .onChange(of: showsInput) { isVisible in
            if isVisible { scheduleKeyboardFocus() }
        }
        .onDisappear {
            focusTask?.cancel()
            isFocused = false
            showsInput = false
            inputRevealedAt = nil
        }
    }

    /// Requests first responder after the field is visible and launch loading has cleared.
    private func scheduleKeyboardFocus() {
        focusTask?.cancel()
        guard showsInput, isLaunchLoadingComplete else {
            if !isLaunchLoadingComplete { isFocused = false }
            return
        }

        focusTask = Task {
            // Wait for the reveal animation so hit testing and layout are stable.
            let revealElapsed = inputRevealedAt.map { Date().timeIntervalSince($0) } ?? inputRevealAnimationDuration
            let revealRemaining = max(0, inputRevealAnimationDuration - revealElapsed)
            try? await Task.sleep(for: .seconds(revealRemaining))
            guard !Task.isCancelled, showsInput, isLaunchLoadingComplete else { return }

            try? await Task.sleep(for: keyboardFocusDelay)
            guard !Task.isCancelled, showsInput, isLaunchLoadingComplete else { return }

            await MainActor.run {
                // Toggle focus once so UIKit reliably presents the keyboard.
                isFocused = false
                isFocused = true
            }
        }
    }

    private var continueButton: some View {
        OnboardingContinueButton(isEnabled: canContinue) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            name = trimmed
            onContinue()
        }
    }
}
