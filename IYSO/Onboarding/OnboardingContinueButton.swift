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

    private var labelFontSize: CGFloat {
        switch layout {
        case .fullWidth: 18
        case .compact: 13
        }
    }

    private var horizontalPadding: CGFloat {
        layout == .compact ? 8 : 0
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                glassBackground
                    .allowsHitTesting(false)

                label
            }
            .frame(maxWidth: layout == .fullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, horizontalPadding)
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
                .font(IYSOFont.inter(size: labelFontSize))
                .foregroundColor(labelIsActive ? IYSOGlassPalette.labelActive : IYSOGlassPalette.labelInactive)
                .lineLimit(layout == .compact ? 1 : nil)
                .minimumScaleFactor(layout == .compact ? 0.75 : 1)
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
            .frame(height: height)
        }
    }
}
