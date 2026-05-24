import SwiftUI

enum AppTab {
    case camera, gallery
}

struct BottomToggle: View {
    @Binding var activeTab: AppTab

    private let toggleWidth: CGFloat = 118
    private let toggleHeight: CGFloat = 64
    private let segmentSize: CGFloat = 47
    /// Asset catalog imageset name for the Memory toggle icon.
    private let memoryToggleLogoAssetName = "MemoryToggleLogo"
    /// Display size for the Memory logo — adjust width/height here.
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

                toggleSegment(
                    tab: .camera,
                    systemName: "camera.fill",
                    iconSize: 18
                )
            }
            .zIndex(1)
        }
        .frame(width: toggleWidth, height: toggleHeight)
    }

    private func memoryToggleSegment() -> some View {
        let isActive = activeTab == .gallery

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { activeTab = .gallery }
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

    private func toggleSegment(tab: AppTab, systemName: String, iconSize: CGFloat) -> some View {
        let isActive = activeTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
        } label: {
            ZStack {
                if isActive {
                    BottomToggleGlassActiveCircle()
                        .allowsHitTesting(false)
                }

                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .regular))
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
