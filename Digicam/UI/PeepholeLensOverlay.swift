import SwiftUI

// MARK: - Figma Glass rim (thin lining on the housing ring; not a glow)

/// Partial glass arcs only — no full 360° ring. Tune visibility here.
private enum PeepholeGlassRimTuning {
    // Placement — upper-left / top (Figma light ~114°)
    /// Rotation for primary glass arc (degrees; 0 = 3 o'clock).
    static let primaryArcRotation: Double = -128
    static let primaryArcTrimStart: CGFloat = 0.60
    static let primaryArcTrimEnd: CGFloat = 0.79

    static let secondaryArcRotation: Double = -118
    static let secondaryArcTrimStart: CGFloat = 0.64
    static let secondaryArcTrimEnd: CGFloat = 0.73

    // Arc appearance
    /// Cool gray-blue glass reflection (keep very low).
    static let primaryArcOpacity: Double = 0.038
    static let secondaryArcOpacity: Double = 0.022
    /// Softness on arcs only (Figma frost — broad, not a stack glow).
    static let primaryArcBlurRatio: CGFloat = 0.012
    static let secondaryArcBlurRatio: CGFloat = 0.009
    static let rimArcLineWeight: CGFloat = 1.05

    /// Faint housing — almost invisible; no full ring read.
    static let housingBrownOpacity: Double = 0.18

    /// Optional full outline — disabled so it does not fight the soft edge blend.
    static let outerHairlineOpacity: Double = 0
    static let outerHairlineWidth: CGFloat = 0.5
}

/// Donut shape between outer and inner diameters — the physical glass ring.
private struct PeepholeGlassAnnulusShape: Shape {
    let outerDiameter: CGFloat
    let innerDiameter: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(
            center: center,
            radius: outerDiameter / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerDiameter / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: true
        )
        return path
    }
}

private extension PeepholeGlassAnnulusShape {
    func glassFill<S: ShapeStyle>(_ style: S) -> some View {
        fill(style, style: FillStyle(eoFill: true))
    }
}

/// Thin frosted glass lining on the housing ring — strokes/annulus only, no outward glow.
struct PeepholeGlassRimOverlay: View {
    let outerDiameter: CGFloat
    let innerDiameter: CGFloat

    private var rimWidth: CGFloat { (outerDiameter - innerDiameter) / 2 }
    private var midlineDiameter: CGFloat { (outerDiameter + innerDiameter) / 2 }
    private var rimMask: PeepholeGlassAnnulusShape {
        PeepholeGlassAnnulusShape(outerDiameter: outerDiameter, innerDiameter: innerDiameter)
    }

    var body: some View {
        ZStack {
            housingBase
            primaryGlassArc
            secondaryGlassArc
            optionalOuterHairline
        }
        .frame(width: outerDiameter, height: outerDiameter)
        .allowsHitTesting(false)
    }

    // MARK: - Layers

    /// Barely-there housing — not a visible full ring.
    private var housingBase: some View {
        rimMask.glassFill(
            Color(red: 0x2a / 255, green: 0x1a / 255, blue: 0x14 / 255)
                .opacity(PeepholeGlassRimTuning.housingBrownOpacity)
        )
    }

    /// Broad cool glass reflection — upper-left only.
    private var primaryGlassArc: some View {
        rimArcStroke(
            diameter: midlineDiameter,
            trimStart: PeepholeGlassRimTuning.primaryArcTrimStart,
            trimEnd: PeepholeGlassRimTuning.primaryArcTrimEnd,
            rotation: PeepholeGlassRimTuning.primaryArcRotation,
            color: Color(red: 0.78, green: 0.84, blue: 0.92)
                .opacity(PeepholeGlassRimTuning.primaryArcOpacity),
            lineWidth: rimWidth * PeepholeGlassRimTuning.rimArcLineWeight,
            blur: outerDiameter * PeepholeGlassRimTuning.primaryArcBlurRatio
        )
    }

    /// Softer inner partial arc — same quadrant, fainter.
    private var secondaryGlassArc: some View {
        rimArcStroke(
            diameter: innerDiameter + rimWidth * 0.2,
            trimStart: PeepholeGlassRimTuning.secondaryArcTrimStart,
            trimEnd: PeepholeGlassRimTuning.secondaryArcTrimEnd,
            rotation: PeepholeGlassRimTuning.secondaryArcRotation,
            color: Color(red: 0.88, green: 0.91, blue: 0.96)
                .opacity(PeepholeGlassRimTuning.secondaryArcOpacity),
            lineWidth: max(0.5, rimWidth * 0.65),
            blur: outerDiameter * PeepholeGlassRimTuning.secondaryArcBlurRatio
        )
    }

    /// Nearly invisible silhouette — avoids graphic outline (opacity ≤ 0.03).
    @ViewBuilder
    private var optionalOuterHairline: some View {
        if PeepholeGlassRimTuning.outerHairlineOpacity > 0 {
            Circle()
                .stroke(
                    Color.white.opacity(PeepholeGlassRimTuning.outerHairlineOpacity),
                    lineWidth: PeepholeGlassRimTuning.outerHairlineWidth
                )
                .frame(width: outerDiameter, height: outerDiameter)
        }
    }

    // MARK: - Helpers

    private func rimArcStroke(
        diameter: CGFloat,
        trimStart: CGFloat,
        trimEnd: CGFloat,
        rotation: Double,
        color: Color,
        lineWidth: CGFloat,
        blur: CGFloat
    ) -> some View {
        Circle()
            .trim(from: trimStart, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .frame(width: diameter, height: diameter)
            .blur(radius: blur)
            .mask(rimMask)
    }

}

// MARK: - Center lens overlay (photo surface; separate from glass housing ring)

private enum PeepholeLensTuning {
    /// Baseline full-lens haze; seed scales this slightly per cover.
    static let baseHazeOpacity: Double = 0.05

    /// Offset haze patch — soft bloom near part of the rim, not a center flash.
    static let patchHazeOpacity: Double = 0.07
    static let patchHazeSizeRatio: CGFloat = 0.55

    /// Primary curved catch-light along the glass edge (arc stroke + blur).
    static let arcHighlightOpacity: Double = 0.11
    static let arcHighlightLineWidthRatio: CGFloat = 0.028
    static let arcHighlightBlurRatio: CGFloat = 0.045

    /// Optional second, fainter crescent on another part of the rim.
    static let secondaryArcOpacity: Double = 0.06
    static let secondaryArcLineWidthRatio: CGFloat = 0.022
    static let secondaryArcBlurRatio: CGFloat = 0.038

    /// One-sided rim glow via angular wash (no sharp streak).
    static let rimGlowOpacity: Double = 0.10
    static let rimGlowBlurRatio: CGFloat = 0.055

    /// Tiny muted glint — only drawn when seed allows; keep peak low.
    static let glintOpacity: Double = 0.07
    static let glintSizeRatio: CGFloat = 0.08
    static let glintBlurRatio: CGFloat = 0.025

    /// Inner shadow at lens edge — kept low so the photo perimeter can dissolve softly.
    static let innerShadowOpacity: Double = 0.28
    static let innerShadowStartRadiusRatio: CGFloat = 0.34
    static let innerShadowEndRadiusRatio: CGFloat = 0.58
}

// MARK: - Per-cover variation (stable from seed)

/// Deterministic reflection layout derived from `reflectionSeed` (e.g. cache key / asset name).
private struct PeepholeLensVariation {
    let rimGlowAngle: Double
    let rimGlowOpacity: Double

    let primaryArcTrimStart: CGFloat
    let primaryArcTrimEnd: CGFloat
    let primaryArcRotation: Double
    let primaryArcOpacity: Double

    let showsSecondaryArc: Bool
    let secondaryArcTrimStart: CGFloat
    let secondaryArcTrimEnd: CGFloat
    let secondaryArcRotation: Double
    let secondaryArcOpacity: Double

    let hazePatchOffsetXRatio: CGFloat
    let hazePatchOffsetYRatio: CGFloat
    let hazePatchOpacity: Double
    let hazePatchSizeRatio: CGFloat

    let hazeMultiplier: Double
    let innerShadowMultiplier: Double

    let showsGlint: Bool
    let glintOffsetXRatio: CGFloat
    let glintOffsetYRatio: CGFloat
    let glintOpacity: Double
    let glintSizeRatio: CGFloat

    init(seed: String) {
        let h = Self.fnv1a64(seed.isEmpty ? "peephole-default" : seed)

        rimGlowAngle = Self.mapped(h, slot: 0, min: -160, max: 40)
        rimGlowOpacity = PeepholeLensTuning.rimGlowOpacity * Self.mapped(h, slot: 1, min: 0.75, max: 1.2)

        primaryArcRotation = Self.mapped(h, slot: 2, min: -200, max: 60)
        let arcSpan = Self.mapped(h, slot: 3, min: 0.14, max: 0.24)
        let arcOffset = Self.mapped(h, slot: 4, min: 0.05, max: 0.22)
        primaryArcTrimStart = CGFloat(arcOffset)
        primaryArcTrimEnd = CGFloat(arcOffset + arcSpan)
        primaryArcOpacity = PeepholeLensTuning.arcHighlightOpacity * Self.mapped(h, slot: 5, min: 0.8, max: 1.25)

        showsSecondaryArc = Self.mapped(h, slot: 6, min: 0, max: 1) > 0.42
        secondaryArcRotation = primaryArcRotation + Self.mapped(h, slot: 7, min: 95, max: 145)
        let secSpan = Self.mapped(h, slot: 8, min: 0.08, max: 0.16)
        let secOffset = Self.mapped(h, slot: 9, min: 0.55, max: 0.78)
        secondaryArcTrimStart = CGFloat(secOffset)
        secondaryArcTrimEnd = CGFloat(secOffset + secSpan)
        secondaryArcOpacity = PeepholeLensTuning.secondaryArcOpacity * Self.mapped(h, slot: 10, min: 0.7, max: 1.15)

        let hazeAngleRad = (Self.mapped(h, slot: 11, min: 0, max: 360) - 90) * .pi / 180
        let hazeDist = Self.mapped(h, slot: 12, min: 0.18, max: 0.32)
        hazePatchOffsetXRatio = CGFloat(cos(hazeAngleRad) * hazeDist)
        hazePatchOffsetYRatio = CGFloat(sin(hazeAngleRad) * hazeDist)
        hazePatchOpacity = PeepholeLensTuning.patchHazeOpacity * Self.mapped(h, slot: 13, min: 0.75, max: 1.3)
        hazePatchSizeRatio = PeepholeLensTuning.patchHazeSizeRatio * Self.mapped(h, slot: 14, min: 0.9, max: 1.1)

        hazeMultiplier = Self.mapped(h, slot: 15, min: 0.85, max: 1.15)
        innerShadowMultiplier = Self.mapped(h, slot: 16, min: 0.92, max: 1.08)

        showsGlint = Self.mapped(h, slot: 17, min: 0, max: 1) > 0.35
        let glintAngleRad = (Self.mapped(h, slot: 18, min: 0, max: 360) - 20) * .pi / 180
        let glintDist = Self.mapped(h, slot: 19, min: 0.12, max: 0.26)
        glintOffsetXRatio = CGFloat(cos(glintAngleRad) * glintDist)
        glintOffsetYRatio = CGFloat(sin(glintAngleRad) * glintDist)
        glintOpacity = PeepholeLensTuning.glintOpacity * Self.mapped(h, slot: 20, min: 0.6, max: 1.0)
        glintSizeRatio = PeepholeLensTuning.glintSizeRatio * Self.mapped(h, slot: 21, min: 0.85, max: 1.2)
    }

    private static func fnv1a64(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    private static func mapped(_ hash: UInt64, slot: Int, min: Double, max: Double) -> Double {
        let slotMix = UInt64(slot) &* 0x9E3779B97F4A7C15
        let slice = hash &+ slotMix ^ (hash >> UInt64((slot % 7) + 1))
        let unit = Double(slice % 10_000) / 9_999.0
        return min + (max - min) * unit
    }
}

// MARK: - Center lens overlay (on photo only)

struct PeepholeLensOverlay: View {
    let diameter: CGFloat
    var reflectionSeed: String = "peephole-default"

    private var variation: PeepholeLensVariation {
        PeepholeLensVariation(seed: reflectionSeed)
    }

    var body: some View {
        let v = variation

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(PeepholeLensTuning.baseHazeOpacity * v.hazeMultiplier),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 0.5
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(PeepholeLensTuning.innerShadowOpacity * v.innerShadowMultiplier),
                        ],
                        center: .center,
                        startRadius: diameter * PeepholeLensTuning.innerShadowStartRadiusRatio,
                        endRadius: diameter * PeepholeLensTuning.innerShadowEndRadiusRatio
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(v.hazePatchOpacity),
                            Color.white.opacity(v.hazePatchOpacity * 0.35),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * v.hazePatchSizeRatio * 0.5
                    )
                )
                .frame(
                    width: diameter * v.hazePatchSizeRatio,
                    height: diameter * v.hazePatchSizeRatio
                )
                .offset(
                    x: diameter * v.hazePatchOffsetXRatio,
                    y: diameter * v.hazePatchOffsetYRatio
                )
                .blur(radius: diameter * 0.07)

            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(v.rimGlowOpacity * 0.35), location: 0.08),
                            .init(color: .white.opacity(v.rimGlowOpacity), location: 0.16),
                            .init(color: .white.opacity(v.rimGlowOpacity * 0.4), location: 0.24),
                            .init(color: .clear, location: 0.38),
                            .init(color: .clear, location: 1),
                        ]),
                        center: .center,
                        angle: .degrees(v.rimGlowAngle)
                    )
                )
                .blur(radius: diameter * PeepholeLensTuning.rimGlowBlurRatio)

            curvedArcHighlight(
                trimStart: v.primaryArcTrimStart,
                trimEnd: v.primaryArcTrimEnd,
                rotation: v.primaryArcRotation,
                opacity: v.primaryArcOpacity,
                lineWidth: diameter * PeepholeLensTuning.arcHighlightLineWidthRatio,
                blur: diameter * PeepholeLensTuning.arcHighlightBlurRatio
            )

            if v.showsSecondaryArc {
                curvedArcHighlight(
                    trimStart: v.secondaryArcTrimStart,
                    trimEnd: v.secondaryArcTrimEnd,
                    rotation: v.secondaryArcRotation,
                    opacity: v.secondaryArcOpacity,
                    lineWidth: diameter * PeepholeLensTuning.secondaryArcLineWidthRatio,
                    blur: diameter * PeepholeLensTuning.secondaryArcBlurRatio
                )
            }

            if v.showsGlint {
                Circle()
                    .fill(Color.white.opacity(v.glintOpacity))
                    .frame(
                        width: diameter * v.glintSizeRatio,
                        height: diameter * v.glintSizeRatio
                    )
                    .offset(
                        x: diameter * v.glintOffsetXRatio,
                        y: diameter * v.glintOffsetYRatio
                    )
                    .blur(radius: diameter * PeepholeLensTuning.glintBlurRatio)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func curvedArcHighlight(
        trimStart: CGFloat,
        trimEnd: CGFloat,
        rotation: Double,
        opacity: Double,
        lineWidth: CGFloat,
        blur: CGFloat
    ) -> some View {
        Circle()
            .trim(from: trimStart, to: trimEnd)
            .stroke(
                Color.white.opacity(opacity),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation))
            .frame(width: diameter * 0.93, height: diameter * 0.93)
            .blur(radius: blur)
    }
}
