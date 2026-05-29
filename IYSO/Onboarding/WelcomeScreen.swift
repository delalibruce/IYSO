import SwiftUI

struct WelcomeScreen: View {
    let name: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("\(name.lowercased()),")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    Text("Welcome to IYSO.")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(Color(white: 0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                Spacer()

                OnboardingContinueButton(title: "let's get started.", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }
}
