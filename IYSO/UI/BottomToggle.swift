import SwiftUI

enum AppTab {
    case camera, gallery
}

/// Shared placement for the root camera toggle and in-flow overlays (e.g. photo detail).
enum BottomToggleLayout {
    static let width: CGFloat = 118
    static let height: CGFloat = 64
    /// Inset above the home indicator — keep in sync with `AppRootView`.
    static let bottomPadding: CGFloat = 20
    /// Extra lift used by the photo detail bottom bar.
    static let detailFlowExtraLift: CGFloat = 34

    /// Total inset from the physical screen bottom (for full-bleed Memory Flow screens).
    static func screenBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        bottomPadding + safeAreaBottom
    }

    /// Matches the physical screen-bottom position used on photo detail.
    static func detailAlignedScreenBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        screenBottomInset(safeAreaBottom: safeAreaBottom) + detailFlowExtraLift
    }
}

extension View {
    /// Pins content to the same distance from the screen bottom as the root `BottomToggle` in `AppRootView`.
    /// Pass `safeAreaBottom` from `SDCardScreenContainer` on full-bleed gallery screens.
    func alignedToBottomToggle(safeAreaBottom: CGFloat = 0) -> some View {
        padding(.bottom, BottomToggleLayout.screenBottomInset(safeAreaBottom: safeAreaBottom))
            .modifier(BottomToggleFullBleedBottomInset(enabled: safeAreaBottom > 0))
    }
}

/// Prevents a second safe-area lift when the parent already extends under the home indicator.
private struct BottomToggleFullBleedBottomInset: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.ignoresSafeArea(edges: .bottom)
        } else {
            content
        }
    }
}

struct BottomToggle: View {
    @Binding var activeTab: AppTab
    /// When set, replaces the default tab-switch on camera icon tap (used to gate entering IYSO Mode).
    var onCameraRequested: (() -> Void)? = nil
    /// When set, replaces the default tab-switch on gallery icon tap (used to show exit modal in IYSO Mode).
    var onGalleryRequested: (() -> Void)? = nil

    private let toggleWidth = BottomToggleLayout.width
    private let toggleHeight = BottomToggleLayout.height
    private let segmentSize: CGFloat = 47
    private let memoryToggleLogoAssetName = "MemoryToggleLogo"
    private let memoryLogoSize: CGFloat = 28
    private let iconActive = Color(white: 0.94)
    private let iconInactive = Color(white: 0.42)

    private func triggerToggleHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    var body: some View {
        ZStack {
            IYSOGlassCapsule()
                .frame(width: toggleWidth, height: toggleHeight)
                .allowsHitTesting(false)

            HStack(spacing: 12) {
                memoryToggleSegment()

                cameraToggleSegment()
            }
            .zIndex(1)
        }
        .frame(width: toggleWidth, height: toggleHeight)
    }

    private func memoryToggleSegment() -> some View {
        let isActive = activeTab == .gallery

        return Button {
            triggerToggleHaptic()
            if let handler = onGalleryRequested {
                handler()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .gallery }
            }
        } label: {
            ZStack {
                if isActive {
                    IYSOGlassActiveCircle()
                        .allowsHitTesting(false)
                }

                Image(memoryToggleLogoAssetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: memoryLogoSize, height: memoryLogoSize)
                    .foregroundColor(isActive ? iconActive : iconInactive)
                    .allowsHitTesting(false)
            }
            .frame(width: segmentSize, height: segmentSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cameraToggleSegment() -> some View {
        let isActive = activeTab == .camera

        return Button {
            triggerToggleHaptic()
            if let handler = onCameraRequested {
                handler()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .camera }
            }
        } label: {
            ZStack {
                if isActive {
                    IYSOGlassActiveCircle()
                        .allowsHitTesting(false)
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(isActive ? iconActive : iconInactive)
            }
            .frame(width: segmentSize, height: segmentSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
