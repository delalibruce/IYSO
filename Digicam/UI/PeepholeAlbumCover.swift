import SwiftUI
import UIKit

// MARK: - Visual palette (Memory Flow gallery + peephole covers)

enum PeepholeVisualPalette: Equatable {
    /// Production Memory Gallery album circles.
    case gallery
    /// Alias for `PeepholeAlbumCoverTestView` sandbox (same tokens as `.gallery`).
    case darkPrototype

    /// Near-black espresso brown used across Memory Flow screens.
    static var memoryFlowBackground: Color {
        Color(red: 0x0f / 255, green: 0x0d / 255, blue: 0x0c / 255)
    }

    var sceneBackground: Color { Self.memoryFlowBackground }

    var edgeMidTone: Color {
        Color(red: 0x18 / 255, green: 0x15 / 255, blue: 0x13 / 255)
    }

    /// Default album glow — #52311F.
    var glowNormal: Color {
        Color(red: 0x52 / 255, green: 0x31 / 255, blue: 0x1F / 255)
    }

    /// New / unviewed album glow.
    var glowNew: Color {
        Color(red: 0x72 / 255, green: 0x52 / 255, blue: 0x36 / 255)
    }

    var housingRimColor: Color {
        Color(red: 0x16 / 255, green: 0x13 / 255, blue: 0x11 / 255)
    }

    var edgeTintCore: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        (0.055, 0.048, 0.044)
    }

    var edgeTintAlpha: CGFloat { 0.48 }

    var edgeDarkenPeakOpacity: Double { 0.78 }

    var edgeMidWashOpacity: Double { 0.28 }

    func glowOuterOpacity(isNew: Bool) -> Double {
        isNew ? 0.40 : 0.33
    }

    func glowInnerOpacity(isNew: Bool) -> Double {
        isNew ? 0.55 : 0.47
    }
}

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

private enum PeepholeAlbumGlowSpread {
    static let outerRadiusMultiplier: CGFloat = 1.02
    static let innerRadiusMultiplier: CGFloat = 0.55
    static let normalBlurRadius: CGFloat = 11
    static let newBlurRadius: CGFloat = 26
}

private struct PeepholeAlbumCircleGlowModifier: ViewModifier {
    let isNew: Bool
    let palette: PeepholeVisualPalette

    func body(content: Content) -> some View {
        let glowColor = isNew ? palette.glowNew : palette.glowNormal
        let blurRadius = isNew ? PeepholeAlbumGlowSpread.newBlurRadius : PeepholeAlbumGlowSpread.normalBlurRadius
        content
            .compositingGroup()
            .shadow(
                color: glowColor.opacity(palette.glowOuterOpacity(isNew: isNew)),
                radius: blurRadius * PeepholeAlbumGlowSpread.outerRadiusMultiplier,
                x: 0,
                y: 0
            )
            .shadow(
                color: glowColor.opacity(palette.glowInnerOpacity(isNew: isNew)),
                radius: blurRadius * PeepholeAlbumGlowSpread.innerRadiusMultiplier,
                x: 0,
                y: 0
            )
    }
}

extension View {
    func peepholeAlbumCircleGlow(isNew: Bool = false, palette: PeepholeVisualPalette = .gallery) -> some View {
        modifier(PeepholeAlbumCircleGlowModifier(isNew: isNew, palette: palette))
    }
}

// MARK: - Photo edge dissolve (feather into dark background; center stays sharp)

private enum PeepholePhotoEdgeTuning {
    static let alphaFeatherStart: CGFloat = 0.72
    static let edgeDarkenStartRatio: CGFloat = 0.64
}

private struct PeepholePhotoSoftEdgeModifier: ViewModifier {
    let diameter: CGFloat
    let palette: PeepholeVisualPalette

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
                        palette.edgeMidTone.opacity(palette.edgeMidWashOpacity * 0.5),
                        palette.edgeMidTone.opacity(palette.edgeMidWashOpacity),
                        palette.sceneBackground.opacity(palette.edgeDarkenPeakOpacity),
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
    /// When true, uses the stronger new/unviewed glow.
    var isNew: Bool = false
    /// `.gallery` for production grid; `.darkPrototype` for the isolated test screen.
    var palette: PeepholeVisualPalette = .gallery

    @State private var processedImage: UIImage?
    @State private var processingGeneration = 0
    @State private var activeCacheKey: String?

    init(
        imageSource: PeepholeImageSource,
        size: CGFloat,
        isNew: Bool = false,
        palette: PeepholeVisualPalette = .gallery
    ) {
        self.imageSource = imageSource
        self.size = size
        self.isNew = isNew
        self.palette = palette

        let innerDiameter = size - 12
        let outputSize = Self.outputPixelSize(for: innerDiameter)
        var initialProcessed: UIImage?
        var initialKey: String?

        if case let .uiImage(image, cacheKey) = imageSource, !Self.isPlaceholderImage(image) {
            let identity = cacheKey ?? "anonymous"
            initialProcessed = PeepholeImageProcessor.cachedImage(
                outputSize: outputSize,
                cacheKey: cacheKey,
                palette: palette
            )
            initialKey = identity
        }

        _processedImage = State(initialValue: initialProcessed)
        _activeCacheKey = State(initialValue: initialKey)
    }

    private var innerDiameter: CGFloat { size - 12 }

    private static func outputPixelSize(for innerDiameter: CGFloat) -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: innerDiameter * scale, height: innerDiameter * scale)
    }

    private static func isPlaceholderImage(_ image: UIImage) -> Bool {
        image.size.width <= 1 && image.size.height <= 1
    }
    private var pngLensOverlay: UIImage? { UIImage(named: "PeepholeLens") }

    /// Stable per-cover value for procedural lens reflections (cache key when available).
    private var lensReflectionSeed: String {
        if case let .uiImage(_, cacheKey) = imageSource, let cacheKey, !cacheKey.isEmpty {
            return cacheKey
        }
        return "peephole-default"
    }

    /// Stable identity for reloads — keyed on cover asset, not UIImage instance.
    private var imageSourceIdentity: String {
        if case let .uiImage(image, cacheKey) = imageSource {
            let key = cacheKey ?? "anonymous"
            if Self.isPlaceholderImage(image) { return "\(key)|placeholder" }
            return key
        }
        return "unknown"
    }

    private var sourceImage: UIImage? {
        guard case let .uiImage(image, _) = imageSource, !Self.isPlaceholderImage(image) else { return nil }
        return image
    }

    /// Processed when ready for this cover; otherwise show the source photo immediately.
    private var displayedPhoto: UIImage? {
        if let processedImage, activeCacheKey == imageSourceIdentity {
            return processedImage
        }
        return sourceImage
    }

    var body: some View {
        ZStack {
            photoAndLensStack
                .peepholeAlbumCircleGlow(isNew: isNew, palette: palette)

            PeepholeGlassRimOverlay(
                outerDiameter: size,
                innerDiameter: innerDiameter,
                palette: palette
            )
        }
        .frame(width: size, height: size)
        .onAppear { processImage() }
        .onChange(of: imageSourceIdentity) { _ in processImage() }
    }

    /// Photo + center lens, feathered at the edge into the dark background.
    private var photoAndLensStack: some View {
        ZStack {
            circularPhoto
            lensOverlay
        }
        .frame(width: innerDiameter, height: innerDiameter)
        .modifier(PeepholePhotoSoftEdgeModifier(diameter: innerDiameter, palette: palette))
        .frame(width: size, height: size)
    }

    private var circularPhoto: some View {
        Group {
            if let displayedPhoto {
                Image(uiImage: displayedPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerDiameter, height: innerDiameter)
            } else {
                Color.clear
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

        if Self.isPlaceholderImage(sourceImage) {
            return
        }

        let outputSize = Self.outputPixelSize(for: innerDiameter)
        let identity = cacheKey ?? imageSourceIdentity

        if let cached = PeepholeImageProcessor.cachedImage(
            outputSize: outputSize,
            cacheKey: cacheKey,
            palette: palette
        ) {
            processedImage = cached
            activeCacheKey = identity
            return
        }

        activeCacheKey = identity
        processingGeneration += 1
        let generation = processingGeneration

        DispatchQueue.global(qos: .userInitiated).async {
            let result = PeepholeImageProcessor.process(
                sourceImage,
                outputSize: outputSize,
                cacheKey: cacheKey,
                palette: palette
            )
            DispatchQueue.main.async {
                guard generation == processingGeneration else { return }
                processedImage = result
                activeCacheKey = identity
            }
        }
    }
}
