import SwiftUI
import UIKit

enum PeepholeImageSource: Equatable {
    case uiImage(UIImage, cacheKey: String? = nil)

    static func == (lhs: PeepholeImageSource, rhs: PeepholeImageSource) -> Bool {
        switch (lhs, rhs) {
        case let (.uiImage(lImage, lKey), .uiImage(rImage, rKey)):
            return lKey == rKey && lImage === rImage
        }
    }
}

// MARK: - Album circle glow (photo container only; not the glass rim or lens overlay)

/// Figma-matched warm ambient glow behind the circular photo.
private enum PeepholeAlbumGlowStyle {
    /// Default albums — shadow #52311F, blur ~15.86
    case normal
    /// New / unviewed albums — shadow #935533, blur ~40
    case newAlbum

    var color: Color {
        switch self {
        case .normal:
            return Color(red: 0x52 / 255, green: 0x31 / 255, blue: 0x1F / 255)
        case .newAlbum:
            return Color(red: 0x93 / 255, green: 0x55 / 255, blue: 0x33 / 255)
        }
    }

    /// Base shadow blur — lower = tighter halo hugging the circle.
    var blurRadius: CGFloat {
        switch self {
        case .normal: 11
        case .newAlbum: 26
        }
    }
}

/// Spread multipliers for the dual-layer warm glow (photo container only).
private enum PeepholeAlbumGlowSpread {
    /// Outer halo radius = `blurRadius * outerRadiusMultiplier`
    static let outerRadiusMultiplier: CGFloat = 1.02
    /// Inner core radius = `blurRadius * innerRadiusMultiplier`
    static let innerRadiusMultiplier: CGFloat = 0.55

    static func outerOpacity(isNew: Bool) -> Double { isNew ? 0.44 : 0.36 }
    static func innerOpacity(isNew: Bool) -> Double { isNew ? 0.66 : 0.58 }
}

private struct PeepholeAlbumCircleGlowModifier: ViewModifier {
    let isNew: Bool

    func body(content: Content) -> some View {
        let style: PeepholeAlbumGlowStyle = isNew ? .newAlbum : .normal
        content
            .compositingGroup()
            .shadow(
                color: style.color.opacity(PeepholeAlbumGlowSpread.outerOpacity(isNew: isNew)),
                radius: style.blurRadius * PeepholeAlbumGlowSpread.outerRadiusMultiplier,
                x: 0,
                y: 0
            )
            .shadow(
                color: style.color.opacity(PeepholeAlbumGlowSpread.innerOpacity(isNew: isNew)),
                radius: style.blurRadius * PeepholeAlbumGlowSpread.innerRadiusMultiplier,
                x: 0,
                y: 0
            )
    }
}

extension View {
    /// Soft warm glow on the circular photo container. Does not affect rim or lens overlays.
    func peepholeAlbumCircleGlow(isNew: Bool = false) -> some View {
        modifier(PeepholeAlbumCircleGlowModifier(isNew: isNew))
    }
}

// MARK: - Photo edge dissolve (feather into dark background; center stays sharp)

private enum PeepholePhotoEdgeTuning {
    /// Full-opacity center extends to here; outer ~10–18% feathers out (lower = wider fade).
    static let alphaFeatherStart: CGFloat = 0.72
    /// Peak of background-matched edge tint (brown-black, not pure black).
    static let edgeDarkenPeakOpacity: Double = 0.62
    /// Where the brown edge wash begins (fraction of radius from center).
    static let edgeDarkenStartRatio: CGFloat = 0.64
    /// Gallery background #1e130f
    static let backgroundColor = Color(red: 0x1e / 255, green: 0x13 / 255, blue: 0x0f / 255)
    /// Slightly warmer mid-edge brown #2a1a14
    static let midEdgeColor = Color(red: 0x2a / 255, green: 0x1a / 255, blue: 0x14 / 255)
}

private struct PeepholePhotoSoftEdgeModifier: ViewModifier {
    let diameter: CGFloat

    func body(content: Content) -> some View {
        content
            .mask(softAlphaMask)
            .overlay(edgeDarkenOverlay)
    }

    private var softAlphaMask: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: PeepholePhotoEdgeTuning.alphaFeatherStart),
                .init(color: .white.opacity(0.82), location: 0.86),
                .init(color: .white.opacity(0.45), location: 0.93),
                .init(color: .white.opacity(0.12), location: 0.97),
                .init(color: .clear, location: 1),
            ]),
            center: .center,
            startRadius: 0,
            endRadius: diameter / 2
        )
    }

    private var edgeDarkenOverlay: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .clear,
                        .clear,
                        PeepholePhotoEdgeTuning.midEdgeColor.opacity(0.22),
                        PeepholePhotoEdgeTuning.midEdgeColor.opacity(0.42),
                        PeepholePhotoEdgeTuning.backgroundColor
                            .opacity(PeepholePhotoEdgeTuning.edgeDarkenPeakOpacity),
                    ],
                    center: .center,
                    startRadius: diameter * PeepholePhotoEdgeTuning.edgeDarkenStartRatio * 0.48,
                    endRadius: diameter * 0.54
                )
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Album cover

struct PeepholeAlbumCover: View {
    let imageSource: PeepholeImageSource
    let size: CGFloat
    /// When true, uses the stronger new/unviewed glow (#935533, blur ~40).
    var isNew: Bool = false

    @State private var processedImage: UIImage?
    @State private var processingGeneration = 0

    private var innerDiameter: CGFloat { size - 12 }
    private var pngLensOverlay: UIImage? { UIImage(named: "PeepholeLens") }

    /// Stable per-cover value for procedural lens reflections (cache key when available).
    private var lensReflectionSeed: String {
        if case let .uiImage(_, cacheKey) = imageSource, let cacheKey, !cacheKey.isEmpty {
            return cacheKey
        }
        return "peephole-default"
    }

    var body: some View {
        ZStack {
            photoAndLensStack
                .peepholeAlbumCircleGlow(isNew: isNew)

            PeepholeGlassRimOverlay(outerDiameter: size, innerDiameter: innerDiameter)
        }
        .frame(width: size, height: size)
        .onAppear { processImage() }
        .onChange(of: imageSource) { _ in processImage() }
    }

    /// Photo + center lens, feathered at the edge into the dark background.
    private var photoAndLensStack: some View {
        ZStack {
            circularPhoto
            lensOverlay
        }
        .frame(width: innerDiameter, height: innerDiameter)
        .modifier(PeepholePhotoSoftEdgeModifier(diameter: innerDiameter))
        .frame(width: size, height: size)
    }

    private var circularPhoto: some View {
        Group {
            if let processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerDiameter, height: innerDiameter)
            } else {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: innerDiameter, height: innerDiameter)
            }
        }
    }

    @ViewBuilder
    private var lensOverlay: some View {
        if let pngLensOverlay {
            Image(uiImage: pngLensOverlay)
                .resizable()
                .scaledToFill()
                .frame(width: innerDiameter, height: innerDiameter)
                .allowsHitTesting(false)
        } else {
            PeepholeLensOverlay(
                diameter: innerDiameter,
                reflectionSeed: lensReflectionSeed
            )
            .allowsHitTesting(false)
        }
    }

    private func processImage() {
        guard case let .uiImage(sourceImage, cacheKey) = imageSource else { return }

        processingGeneration += 1
        let generation = processingGeneration
        processedImage = nil

        let outputSize = CGSize(
            width: innerDiameter * UIScreen.main.scale,
            height: innerDiameter * UIScreen.main.scale
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let result = PeepholeImageProcessor.process(
                sourceImage,
                outputSize: outputSize,
                cacheKey: cacheKey
            )
            DispatchQueue.main.async {
                guard generation == processingGeneration else { return }
                processedImage = result
            }
        }
    }
}
