import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case nameEntry = 0
    case welcome
    case explainer
    case capturePermissionSetup
    case appBlockingSetup
    case memoryModeEntry
}

struct OnboardingFlowView: View {
    @ObservedObject var appBlocking: AppBlockingManager
    var isLaunchLoadingComplete: Bool = true
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .nameEntry
    @State private var name: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            stepView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsFlowBackButton {
                HStack {
                    OnboardingBackButton(action: goBack)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    private var showsFlowBackButton: Bool {
        step != .nameEntry && step != .explainer
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .nameEntry:
            NameEntryScreen(
                name: $name,
                isLaunchLoadingComplete: isLaunchLoadingComplete,
                onContinue: advance
            )

        case .welcome:
            WelcomeScreen(name: name, onContinue: advance)

        case .explainer:
            ExplainerFlowView(
                onComplete: advance,
                onBack: goBack
            )

        case .capturePermissionSetup:
            CapturePermissionSetupScreen(onContinue: advance)

        case .appBlockingSetup:
            AppBlockingSetupScreen(
                appBlocking: appBlocking,
                onContinue: advanceFromBlockingSetup,
                onSkip: advanceFromBlockingSetup
            )

        case .memoryModeEntry:
            MemoryModeEntryScreen(onComplete: completeOnboarding)
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard let current = OnboardingStep(rawValue: step.rawValue),
              let next = OnboardingStep(rawValue: current.rawValue + 1) else { return }
        step = next
    }

    private func goBack() {
        guard let current = OnboardingStep(rawValue: step.rawValue),
              let previous = OnboardingStep(rawValue: current.rawValue - 1) else { return }
        step = previous
    }

    private func advanceFromBlockingSetup() {
        advance(to: .memoryModeEntry)
    }

    private func advance(to target: OnboardingStep) {
        step = target
    }

    // MARK: - Completion

    private func completeOnboarding() {
        UserDefaults.standard.set(name, forKey: "userName")
        onComplete()
    }
}
