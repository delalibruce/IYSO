import SwiftUI

struct OnboardingProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current - 1 ? Color.white : Color(white: 1, opacity: 0.3))
                    .frame(width: index == current - 1 ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}
