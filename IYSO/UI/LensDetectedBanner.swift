import SwiftUI

struct LensDetectedBanner: View {
    var body: some View {
        Text("Lens detected - start shooting")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(Capsule().strokeBorder(Color(white: 1, opacity: 0.14), lineWidth: 0.5))
            )
    }
}
