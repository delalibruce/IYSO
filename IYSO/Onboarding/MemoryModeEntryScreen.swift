import SwiftUI

struct MemoryModeEntryScreen: View {
    let name: String
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome to iyso, \(name).")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("You're ready to shoot.")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color(white: 0.75))

                        Text("IYSO Mode will turn on with your apps shielded. Exit when you're done to view your memory card.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(white: 0.45))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                Spacer()

                OnboardingContinueButton(title: "open my camera", action: onComplete)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }
}
