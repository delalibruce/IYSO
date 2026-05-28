import SwiftUI

// MARK: - Glass styling (shared by BottomToggle, onboarding CTAs, etc.)

enum IYSOGlassPalette {
    static let warmDarkTint = Color(red: 0.22, green: 0.17, blue: 0.15)
    static let warmAccent = Color(red: 127 / 255, green: 104 / 255, blue: 96 / 255)

    static let outerStroke = Color.white.opacity(0.15)
    static let innerHighlight = Color.white.opacity(0.1)
    static let outerShadow = Color.black.opacity(0.3)

    static let activeOuterStroke = Color.white.opacity(0.2)
    static let activeInnerHighlight = Color.white.opacity(0.12)
    static let activeShadow = Color.black.opacity(0.22)

    static let labelActive = Color(white: 0.94)
    static let labelInactive = Color(white: 0.42)
}

struct IYSOGlassSurface<S: InsettableShape>: View {
    let shape: S
    var isEmphasized: Bool = false

    private var warmTintOpacity: Double { isEmphasized ? 0.4 : 0.28 }
    private var warmAccentOpacity: Double { isEmphasized ? 0.14 : 0.09 }
    private var lightWashOpacity: Double { isEmphasized ? 0.08 : 0.06 }
    private var depthWashOpacity: Double { isEmphasized ? 0.04 : 0.05 }

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(IYSOGlassPalette.warmDarkTint.opacity(warmTintOpacity))
            }
            .overlay {
                shape.fill(IYSOGlassPalette.warmAccent.opacity(warmAccentOpacity))
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
                        ? IYSOGlassPalette.activeOuterStroke
                        : IYSOGlassPalette.outerStroke,
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
                                    ? IYSOGlassPalette.activeInnerHighlight
                                    : IYSOGlassPalette.innerHighlight,
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
                    ? IYSOGlassPalette.activeShadow
                    : IYSOGlassPalette.outerShadow,
                radius: isEmphasized ? 7 : 15,
                x: 0,
                y: isEmphasized ? 3 : 8
            )
            .allowsHitTesting(false)
    }
}

struct IYSOGlassCapsule: View {
    var isEmphasized: Bool = false

    var body: some View {
        IYSOGlassSurface(shape: Capsule(), isEmphasized: isEmphasized)
            .allowsHitTesting(false)
    }
}

struct IYSOGlassActiveCircle: View {
    var body: some View {
        IYSOGlassSurface(shape: Circle(), isEmphasized: true)
            .frame(width: 47, height: 47)
            .allowsHitTesting(false)
    }
}
