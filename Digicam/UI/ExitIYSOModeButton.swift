import SwiftUI

/// Capsule control shown on the camera screen while IYSO Mode is active.
struct ExitIYSOModeButton: View {
    var isPressed: Bool = false
    /// Scales padding and type together (e.g. onboarding animation).
    var magnification: CGFloat = 1

    private var fontSize: CGFloat { 13 * magnification }
    private var horizontalPadding: CGFloat { 12 * magnification }
    private var verticalPadding: CGFloat { 7 * magnification }

    var body: some View {
        Text("Exit IYSO Mode")
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(buttonBackground)
            .shadow(
                color: Color.white.opacity(isPressed ? 0.2 : 0),
                radius: isPressed ? 8 : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isPressed ? 0.96 : 1, anchor: .center)
            .brightness(isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.18), value: isPressed)
    }

    private var buttonBackground: some View {
        Capsule()
            .fill(Color(white: 1, opacity: isPressed ? 0.18 : 0.12))
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color(white: 1, opacity: isPressed ? 0.28 : 0.2),
                        lineWidth: 0.5
                    )
            )
    }
}
