import SwiftUI

struct LensDetectedScreen: View {
    let name: String
    let onComplete: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    checkmarkView

                    VStack(spacing: 10) {
                        Text("You're all set, \(name).")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 4) {
                            Text("Your lens is connected. IYSO Mode is on.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color(white: 0.65))

                            Text("Snap away.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color(white: 0.4))
                        }
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                OnboardingContinueButton(
                    title: "open my camera",
                    action: {
                        NFCLensManager.shared.onSuccess = { onComplete() }
                        NFCLensManager.shared.onFailure = { _ in onComplete() }
                        NFCLensManager.shared.startScan(purpose: .register)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showCheckmark = true
            }
        }
    }

    private var checkmarkView: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.0, green: 0.55, blue: 0.3, opacity: 0.2))
                .frame(width: 110, height: 110)
                .scaleEffect(showCheckmark ? 1 : 0.5)
                .opacity(showCheckmark ? 1 : 0)

            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(Color(red: 0, green: 0.85, blue: 0.4))
                .scaleEffect(showCheckmark ? 1 : 0.3)
                .opacity(showCheckmark ? 1 : 0)
        }
    }
}
