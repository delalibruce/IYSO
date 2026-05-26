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

    /// Total inset from the physical screen bottom (for full-bleed Memory Flow screens).
    static func screenBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        bottomPadding + safeAreaBottom
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
    /// When set, replaces the default tab-switch on camera icon tap (used to gate behind NFC).
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

    var body: some View {
        ZStack {
            BottomToggleGlassCapsule()
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
            if let handler = onGalleryRequested {
                handler()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .gallery }
            }
        } label: {
            ZStack {
                if isActive {
                    BottomToggleGlassActiveCircle()
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
            if let handler = onCameraRequested {
                handler()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { activeTab = .camera }
            }
        } label: {
            ZStack {
                if isActive {
                    BottomToggleGlassActiveCircle()
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

// MARK: - Glass styling (material-based; `.glassEffect` is skipped on decorative layers because it can intercept touches even with `.allowsHitTesting(false)`.)

private enum BottomToggleGlassPalette {
    static let warmDarkTint = Color(red: 0.22, green: 0.17, blue: 0.15)
    static let warmAccent = Color(red: 127 / 255, green: 104 / 255, blue: 96 / 255)

    static let outerStroke = Color.white.opacity(0.15)
    static let innerHighlight = Color.white.opacity(0.1)
    static let outerShadow = Color.black.opacity(0.3)

    static let activeOuterStroke = Color.white.opacity(0.2)
    static let activeInnerHighlight = Color.white.opacity(0.12)
    static let activeShadow = Color.black.opacity(0.22)
}

private struct BottomToggleGlassCapsule: View {
    var body: some View {
        BottomToggleGlassSurface(shape: Capsule(), isEmphasized: false)
            .allowsHitTesting(false)
    }
}

private struct BottomToggleGlassActiveCircle: View {
    var body: some View {
        BottomToggleGlassSurface(shape: Circle(), isEmphasized: true)
            .frame(width: 47, height: 47)
            .allowsHitTesting(false)
    }
}

private struct BottomToggleGlassSurface<S: InsettableShape>: View {
    let shape: S
    let isEmphasized: Bool

    private var warmTintOpacity: Double { isEmphasized ? 0.4 : 0.28 }
    private var warmAccentOpacity: Double { isEmphasized ? 0.14 : 0.09 }
    private var lightWashOpacity: Double { isEmphasized ? 0.08 : 0.06 }
    private var depthWashOpacity: Double { isEmphasized ? 0.04 : 0.05 }

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(BottomToggleGlassPalette.warmDarkTint.opacity(warmTintOpacity))
            }
            .overlay {
                shape.fill(BottomToggleGlassPalette.warmAccent.opacity(warmAccentOpacity))
            }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(lightWashOpacity),
                            Color.clear,
                            Color.black.opacity(depthWashOpacity),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    isEmphasized
                        ? BottomToggleGlassPalette.activeOuterStroke
                        : BottomToggleGlassPalette.outerStroke,
                    lineWidth: 0.75
                )
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isEmphasized
                                    ? BottomToggleGlassPalette.activeInnerHighlight
                                    : BottomToggleGlassPalette.innerHighlight,
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.72, y: 0.78)
                        ),
                        lineWidth: isEmphasized ? 0.85 : 0.65
                    )
            }
            .compositingGroup()
            .shadow(
                color: isEmphasized
                    ? BottomToggleGlassPalette.activeShadow
                    : BottomToggleGlassPalette.outerShadow,
                radius: isEmphasized ? 7 : 15,
                x: 0,
                y: isEmphasized ? 3 : 8
            )
            .allowsHitTesting(false)
    }
}
