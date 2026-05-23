import CoreImage
import UIKit

enum PeepholeImageProcessor {

    // MARK: - Tuning constants (adjust on test screen)

    /// Outward barrel bulge; higher = stronger center magnification / edge bend.
    private static let bumpScale: Float = 0.20
    /// How far from center the fisheye warp reaches; higher = gentler curve across more of the circle.
    private static let bumpRadiusMultiplier: CGFloat = 0.54

    /// Vignette darkness at the edge; lower = less harsh black ring.
    private static let vignetteIntensity: Float = 1.65
    /// Vignette falloff spread; higher = wider, gentler fade (darkening pushed outward).
    private static let vignetteRadius: Float = 3.35

    /// Max blur at the outer rim only; keeps center sharp.
    private static let edgeBlurRadius: Float = 2.8
    /// Normalized radius where edge blur begins (higher = sharper center longer).
    private static let edgeBlurStart: CGFloat = 0.58
    /// Normalized radius where edge blur reaches full strength (wider = gradual feather).
    private static let edgeBlurEnd: CGFloat = 0.90

    private static let warmEdgeTintStart: CGFloat = 0.58
    private static let warmEdgeTintEnd: CGFloat = 0.98

    // MARK: - Cache

    /// Bump when fisheye, vignette, tint, or edge-softness constants change to invalidate cached output.
    static let processingVersion = 1

    private static let ciContext = CIContext(options: nil)
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

  /// Returns a previously processed image when available (safe to call on the main thread).
    static func cachedImage(
        outputSize: CGSize,
        cacheKey: String?,
        palette: PeepholeVisualPalette = .gallery
    ) -> UIImage? {
        let key = makeCacheKey(outputSize: outputSize, cacheKey: cacheKey, palette: palette)
        return cache.object(forKey: key as NSString)
    }

    static func process(
        _ image: UIImage,
        outputSize: CGSize,
        cacheKey: String? = nil,
        palette: PeepholeVisualPalette = .gallery
    ) -> UIImage {
        let pixelSize = pixelDimensions(for: outputSize)
        let key = makeCacheKey(outputSize: outputSize, cacheKey: cacheKey, palette: palette)
        if let cached = cache.object(forKey: key as NSString) { return cached }

        guard let processed = applyPipeline(to: image, outputSize: pixelSize, palette: palette) else { return image }
        let cost = processed.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(processed, forKey: key as NSString, cost: cost)
        return processed
    }

    /// Clears all processed peephole images. Call after changing `processingVersion` or visual pipeline constants.
    static func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Pipeline

    private static func applyPipeline(to image: UIImage, outputSize: CGSize, palette: PeepholeVisualPalette) -> UIImage? {
        guard var ciImage = CIImage(image: image) ?? (image.cgImage.map { CIImage(cgImage: $0) }) else {
            return nil
        }

        ciImage = centerSquareCrop(ciImage)
        ciImage = scaleToFill(ciImage, targetSize: outputSize)

        let extent = ciImage.extent
        let center = CIVector(x: extent.midX, y: extent.midY)
        let side = min(extent.width, extent.height)

        if let bump = CIFilter(name: "CIBumpDistortion") {
            bump.setValue(ciImage, forKey: kCIInputImageKey)
            bump.setValue(center, forKey: kCIInputCenterKey)
            bump.setValue(side * bumpRadiusMultiplier, forKey: kCIInputRadiusKey)
            bump.setValue(bumpScale, forKey: kCIInputScaleKey)
            if let output = bump.outputImage { ciImage = output.cropped(to: extent) }
        }

        if let vignette = CIFilter(name: "CIVignette") {
            vignette.setValue(ciImage, forKey: kCIInputImageKey)
            vignette.setValue(vignetteIntensity, forKey: kCIInputIntensityKey)
            vignette.setValue(vignetteRadius, forKey: kCIInputRadiusKey)
            if let output = vignette.outputImage { ciImage = output.cropped(to: extent) }
        }

        if let tinted = applyWarmEdgeTint(to: ciImage, extent: extent, palette: palette) {
            ciImage = tinted
        }

        if edgeBlurRadius > 0, let softened = applyEdgeSoftness(to: ciImage, extent: extent) {
            ciImage = softened
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }

    private static func applyEdgeSoftness(to image: CIImage, extent: CGRect) -> CIImage? {
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(edgeBlurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage?.cropped(to: extent) else { return image }

        let mask = radialEdgeMask(extent: extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else { return image }
        blend.setValue(blurred, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    /// Radial warm-brown wash on the outer band — atmospheric, not a black vignette ring.
    private static func applyWarmEdgeTint(to image: CIImage, extent: CGRect, palette: PeepholeVisualPalette) -> CIImage? {
        let side = min(extent.width, extent.height)
        let tint = palette.edgeTintCore
        let gradient = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                "inputRadius0": side * warmEdgeTintStart,
                "inputRadius1": side * warmEdgeTintEnd,
                "inputColor0": CIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: 0),
                "inputColor1": CIColor(red: tint.red, green: tint.green, blue: tint.blue, alpha: palette.edgeTintAlpha),
            ]
        )
        guard let tint = gradient?.outputImage?.cropped(to: extent) else { return image }
        guard let blend = CIFilter(name: "CISourceOverCompositing") else { return image }
        blend.setValue(tint, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private static func radialEdgeMask(extent: CGRect) -> CIImage {
        let side = min(extent.width, extent.height)
        let start = side * edgeBlurStart
        let end = side * edgeBlurEnd
        let gradient = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                "inputRadius0": start,
                "inputRadius1": end,
                "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
            ]
        )
        return gradient?.outputImage?.cropped(to: extent)
            ?? CIImage(color: .black).cropped(to: extent)
    }

    private static func centerSquareCrop(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let side = min(extent.width, extent.height)
        let originX = extent.midX - side / 2
        let originY = extent.midY - side / 2
        return image.cropped(to: CGRect(x: originX, y: originY, width: side, height: side))
    }

    private static func scaleToFill(_ image: CIImage, targetSize: CGSize) -> CIImage {
        let extent = image.extent
        let scaleX = targetSize.width / extent.width
        let scaleY = targetSize.height / extent.height
        let scale = max(scaleX, scaleY)
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    /// `outputSize` is already in pixels (display diameter × screen scale).
    private static func pixelDimensions(for outputSize: CGSize) -> CGSize {
        outputSize
    }

    private static func makeCacheKey(
        outputSize: CGSize,
        cacheKey: String?,
        palette: PeepholeVisualPalette
    ) -> String {
        let pixelSize = pixelDimensions(for: outputSize)
        let paletteTag = palette == .darkPrototype ? "dark" : "gallery"
        let scaleTag = Int(UIScreen.main.scale)
        let identity = cacheKey ?? "anonymous"
        return "\(identity)|v\(processingVersion)|\(Int(pixelSize.width))x\(Int(pixelSize.height))@\(scaleTag)|\(paletteTag)"
    }
}
