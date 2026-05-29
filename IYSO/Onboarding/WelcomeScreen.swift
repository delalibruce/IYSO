import SwiftUI

struct WelcomeScreen: View {
    let name: String
    let onContinue: () -> Void

    private var formattedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased() + trimmed.dropFirst().lowercased()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("\(formattedName),")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("welcome to IYSO.")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color(white: 0.85))

                        Text("we believe that moments deserve to be captured without distraction.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(white: 0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                Spacer()

                OnboardingContinueButton(title: "here's how it works.", action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }
}
