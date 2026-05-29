import SwiftUI

struct MemoryModeEntryScreen: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text("It's time to enter IYSO mode")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("you're ready to shoot")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(white: 0.75))
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
