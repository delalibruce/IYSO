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

    /// Warm brown edge tint (#1e130f family) — blends photo into background, not pure black.
    private static let warmEdgeTintAlpha: CGFloat = 0.38
    private static let warmEdgeTintStart: CGFloat = 0.58
    private static let warmEdgeTintEnd: CGFloat = 0.98

    // MARK: - Cache

    private static let ciContext = CIContext(options: nil)
    private static let cache = NSCache<NSString, UIImage>()

    static func process(_ image: UIImage, outputSize: CGSize, cacheKey: String? = nil) -> UIImage {
        let pixelSize = CGSize(
            width: outputSize.width * image.scale,
            height: outputSize.height * image.scale
        )
        let key = (cacheKey ?? imageCacheKey(for: image)) + "|\(Int(pixelSize.width))x\(Int(pixelSize.height))"
        if let cached = cache.object(forKey: key as NSString) { return cached }

        guard let processed = applyPipeline(to: image, outputSize: pixelSize) else { return image }
        cache.setObject(processed, forKey: key as NSString)
        return processed
    }

    static func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Pipeline

    private static func applyPipeline(to image: UIImage, outputSize: CGSize) -> UIImage? {
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

        if let tinted = applyWarmEdgeTint(to: ciImage, extent: extent) {
            ciImage = tinted
        }

        if edgeBlurRadius > 0, let softened = applyEdgeSoftness(to: ciImage, extent: extent) {
            ciImage = softened
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
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
    private static func applyWarmEdgeTint(to image: CIImage, extent: CGRect) -> CIImage? {
        let side = min(extent.width, extent.height)
        let gradient = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": CIVector(x: extent.midX, y: extent.midY),
                "inputRadius0": side * warmEdgeTintStart,
                "inputRadius1": side * warmEdgeTintEnd,
                "inputColor0": CIColor(red: 0.12, green: 0.075, blue: 0.06, alpha: 0),
                "inputColor1": CIColor(red: 0.12, green: 0.075, blue: 0.06, alpha: warmEdgeTintAlpha),
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

    private static func imageCacheKey(for image: UIImage) -> String {
        if let data = image.jpegData(compressionQuality: 0.1) {
            return String(data.hashValue)
        }
        return String(ObjectIdentifier(image).hashValue)
    }
}
