import SwiftUI

struct MemoryModeEntryScreen: View {
    let onComplete: () -> Void

    private let iysoModeFontSize: CGFloat = 58
    private let iysoModeLetterSpacingPercent: CGFloat = 8

    var body: some View {
        ZStack {
            IYSOLaunchBackground(orbCenterYOffset: -40)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                copyBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                OnboardingContinueButton(title: "let's begin", action: onComplete)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
    }

    private var copyBlock: some View {
        VStack(spacing: 20) {
            Text("It's time to enter")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("IYSO Mode")
                .font(IYSOFont.bootzy(size: iysoModeFontSize))
                .tracking(
                    IYSOFont.tracking(
                        percentOfFontSize: iysoModeLetterSpacingPercent,
                        fontSize: iysoModeFontSize
                    )
                )
                .foregroundStyle(Color(white: 0.92))
                .fixedSize()
                .multilineTextAlignment(.center)

            Text("you're ready to shoot.")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Color(white: 0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
    }
}
