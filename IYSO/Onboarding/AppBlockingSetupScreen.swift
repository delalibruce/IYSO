import SwiftUI

struct AppBlockingSetupScreen: View {
    @ObservedObject var appBlocking: AppBlockingManager
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerText
                        BlockedAppsSelectionPanel()
                            .environmentObject(appBlocking)
                    }
                    .padding(.bottom, 120)
                }

                bottomButtons
            }
        }
    }

    // MARK: - Header

    private var headerText: some View {
        Text("Choose apps you want to block while you shoot.")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 28)
    }

    // MARK: - Bottom

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            OnboardingContinueButton(action: onContinue)

            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        )
    }
}
