import SwiftUI

enum OnboardingButtonLayout {
    /// Full-width pill — matches `BottomToggle` height.
    case fullWidth
    /// Inline control for permission rows and card actions.
    case compact
}

/// Glass CTA matching `BottomToggle` styling — Inter label on `IYSOGlassSurface`.
struct OnboardingContinueButton: View {
    var title: String = "continue"
    var isEnabled: Bool = true
    /// Muted label and glass while keeping the control tappable (e.g. denied → Settings).
    var muted: Bool = false
    var layout: OnboardingButtonLayout = .fullWidth
    var showsLoading: Bool = false
    let action: () -> Void

    private var labelIsActive: Bool { isEnabled && !muted }
    private var glassIsEmphasized: Bool { isEnabled && !muted }

    private var height: CGFloat {
        switch layout {
        case .fullWidth: BottomToggleLayout.height
        case .compact: 36
        }
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                glassBackground
                    .allowsHitTesting(false)

                label
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || showsLoading)
        .animation(.easeInOut(duration: 0.15), value: labelIsActive)
    }

    @ViewBuilder
    private var label: some View {
        if showsLoading {
            ProgressView()
                .tint(IYSOGlassPalette.labelActive)
                .frame(width: 20, height: 20)
        } else {
            Text(title)
                .font(labelFont)
                .foregroundColor(labelIsActive ? IYSOGlassPalette.labelActive : IYSOGlassPalette.labelInactive)
                .lineLimit(1)
        }
    }

    private var labelFont: Font {
        switch layout {
        case .fullWidth:
            return IYSOFont.inter(size: 18)
        case .compact:
            return .system(size: 13, weight: .semibold)
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        switch layout {
        case .fullWidth:
            IYSOGlassCapsule(isEmphasized: glassIsEmphasized)
                .frame(height: height)
        case .compact:
            IYSOGlassSurface(
                shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                isEmphasized: glassIsEmphasized
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
