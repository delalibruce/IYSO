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
                        Text("Your memory card is ready.")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(Color(white: 0.75))

                        Text("Connect your lens when you're ready to shoot.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(white: 0.45))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)

                Spacer()

                Button(action: onComplete) {
                    Text("Open my memory card")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}
