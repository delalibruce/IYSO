import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case nameEntry = 0
    case welcome
    case explainerLens
    case explainerIYSO
    case explainerMemory
    case explainerNoPeeking
    case capturePermissionSetup
    case appBlockingSetup
    case nfcCalibration
    case lensDetected
    case memoryModeEntry
}

struct OnboardingFlowView: View {
    @ObservedObject var nfc: NFCManager
    @ObservedObject var appBlocking: AppBlockingManager
    var isLaunchLoadingComplete: Bool = true
    let onComplete: (_ enteredIYSOMode: Bool) -> Void

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
        .animation(.easeInOut(duration: 0.28), value: step)
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

        case .explainerLens:
            ExplainerScreen(config: .lens, onContinue: advance)

        case .explainerIYSO:
            ExplainerScreen(config: .iysoMode, onContinue: advance)

        case .explainerMemory:
            ExplainerScreen(config: .memoryMode, onContinue: advance)

        case .explainerNoPeeking:
            ExplainerScreen(config: .noPeeking, onContinue: advance)

        case .capturePermissionSetup:
            CapturePermissionSetupScreen(onContinue: advance)

        case .appBlockingSetup:
            AppBlockingSetupScreen(
                appBlocking: appBlocking,
                onContinue: advance,
                onSkip: advance
            )

        case .nfcCalibration:
            NFCCalibrationScreen(
                nfc: nfc,
                onLensConnected: { advance(to: .lensDetected) },
                onSkip: { advance(to: .memoryModeEntry) }
            )

        case .lensDetected:
            LensDetectedScreen(name: name, onComplete: { completeWithIYSO() })

        case .memoryModeEntry:
            MemoryModeEntryScreen(name: name, onComplete: { completeWithMemory() })
        }
    }

    // MARK: - Navigation

    private func advance() {
        guard let current = OnboardingStep(rawValue: step.rawValue),
              let next = OnboardingStep(rawValue: current.rawValue + 1) else { return }
        step = next
    }

    private func advance(to target: OnboardingStep) {
        step = target
    }

    // MARK: - Completion

    private func completeWithIYSO() {
        UserDefaults.standard.set(name, forKey: "userName")
        onComplete(true)
    }

    private func completeWithMemory() {
        UserDefaults.standard.set(name, forKey: "userName")
        onComplete(false)
    }
}
