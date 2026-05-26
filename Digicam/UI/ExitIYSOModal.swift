import SwiftUI

struct ExitIYSOModal: View {
    let onExit: () -> Void
    let onKeepShooting: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onKeepShooting)

            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Exit IYSO Mode?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Your Memory Card will unlock, and the camera will lock until your lens is connected again.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(white: 0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()
                .background(Color(white: 1, opacity: 0.12))

            HStack(spacing: 0) {
                Button(action: onExit) {
                    Text("Exit")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(width: 0.5, height: 48)
                    .background(Color(white: 1, opacity: 0.12))

                Button(action: onKeepShooting) {
                    Text("Keep Shooting")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 310)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(white: 1, opacity: 0.12), lineWidth: 0.5)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
