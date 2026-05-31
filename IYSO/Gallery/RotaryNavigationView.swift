import SwiftUI
import Photos
import UIKit

// Arc-shaped wheel carousel shown below the main photo in PhotoDetailView.
// All album photos scroll along a curved track; the centered item is selected.
struct RotaryNavigationView: View {
    let assets: [PHAsset]
    let library: PhotoLibraryManager
    @Binding var currentIndex: Int
    @Binding var isDragging: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var gestureStartOffset: CGFloat = 0
    @State private var lastDragHapticIndex: Int?

    private let baseDiameter: CGFloat = 75
    private let selectedDiameter: CGFloat = 91
    private let itemSpacing: CGFloat = 10
    /// Quadratic drop per pitch unit — controls how steep the arch feels.
    private let archDropPerUnit: CGFloat = 26
    /// Pulls outermost edge thumbnails slightly inward so more of them stays visible.
    private let edgeInwardNudge: CGFloat = 8
    /// Extra breathing room between the selected center and its immediate neighbors.
    private let centerNeighborExtra: CGFloat = 3
    /// Pulls the next ring inward so those neighbors sit closer to the outer circles.
    private let outerFlankCompress: CGFloat = 2
    /// Movement past this count as a drag; shorter gestures stay taps on thumbnails.
    private let dragActivationDistance: CGFloat = 10
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    /// Every thumbnail occupies the same slot width so center-to-center spacing stays even.
    private var slotWidth: CGFloat { selectedDiameter }
    private var pitch: CGFloat { slotWidth + itemSpacing }
    private var selectedScale: CGFloat { selectedDiameter / baseDiameter }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let trackOffset = centerX - slotWidth / 2 - CGFloat(currentIndex) * pitch + dragOffset

            HStack(spacing: itemSpacing) {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    let horizontalDist = CGFloat(index - currentIndex) * pitch + dragOffset
                    let normalizedDist = abs(horizontalDist) / pitch

                    carouselItem(
                        for: asset,
                        at: index,
                        normalizedDist: normalizedDist,
                        horizontalDist: horizontalDist
                    )
                }
            }
            .offset(x: trackOffset)
            // Leading alignment so `trackOffset` places the selected slot on `centerX`
            // (top-center alignment double-shifts when there is only one thumbnail).
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .highPriorityGesture(carouselDrag)
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .onAppear {
            haptic.prepare()
            if assets.count == 1, currentIndex != 0 {
                currentIndex = 0
                dragOffset = 0
            }
        }
    }

    // MARK: - Arch geometry

    private func archDrop(for horizontalDist: CGFloat) -> CGFloat {
        let t = horizontalDist / pitch
        return min(t * t * archDropPerUnit, 72)
    }

    /// Nudges the left/right edge thumbnails toward center so they peek in a little more.
    private func horizontalEdgeNudge(for horizontalDist: CGFloat) -> CGFloat {
        let slotsFromCenter = abs(horizontalDist) / pitch
        guard slotsFromCenter > 1.5 else { return 0 }
        let ramp = min((slotsFromCenter - 1.5) / 0.5, 1)
        let nudge = edgeInwardNudge * ramp
        return horizontalDist > 0 ? -nudge : nudge
    }

    /// Widens center↔neighbor gaps while tightening neighbor↔outer gaps.
    private func flankSpacingAdjust(for horizontalDist: CGFloat) -> CGFloat {
        let slotsFromCenter = horizontalDist / pitch
        let neighborWeight = bumpWeight(slotsFromCenter: slotsFromCenter, peak: 1)
        let outerWeight = bumpWeight(slotsFromCenter: slotsFromCenter, peak: 2)

        let neighborNudge = (slotsFromCenter >= 0 ? 1 : -1) * neighborWeight * centerNeighborExtra
        let outerNudge = (slotsFromCenter >= 0 ? -1 : 1) * outerWeight * outerFlankCompress
        return neighborNudge + outerNudge
    }

    private func bumpWeight(slotsFromCenter: CGFloat, peak: CGFloat) -> CGFloat {
        let distFromPeak = abs(abs(slotsFromCenter) - peak)
        return max(0, 1 - distFromPeak / 0.55)
    }

    private func horizontalItemOffset(for horizontalDist: CGFloat) -> CGFloat {
        horizontalEdgeNudge(for: horizontalDist) + flankSpacingAdjust(for: horizontalDist)
    }

    // MARK: - Carousel item

    @ViewBuilder
    private func carouselItem(
        for asset: PHAsset,
        at index: Int,
        normalizedDist: CGFloat,
        horizontalDist: CGFloat
    ) -> some View {
        let isCentered = abs(horizontalDist) < pitch * 0.45
        let thumbScale = scale(for: normalizedDist)
        let hitSize = baseDiameter * thumbScale

        ZStack {
            RotaryThumbCell(
                asset: asset,
                library: library,
                diameter: baseDiameter,
                isCentered: isCentered
            )
            .scaleEffect(thumbScale)
            .saturation(isCentered ? 1 : 0)
            .opacity(opacity(for: normalizedDist))
            .brightness(isCentered ? 0 : -0.08)
        }
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .frame(width: slotWidth, height: slotWidth)
        .offset(
            x: horizontalItemOffset(for: horizontalDist),
            y: archDrop(for: horizontalDist)
        )
        .animation(isDragging ? nil : .easeInOut(duration: 0.25), value: currentIndex)
        .animation(isDragging ? nil : .easeInOut(duration: 0.25), value: dragOffset)
        .onTapGesture {
            guard !isDragging else { return }
            selectIndex(index)
        }
        .zIndex(zIndex(for: normalizedDist))
    }

    /// Keeps the centered thumbnail on top visually; neighbors stay above the track for taps.
    private func zIndex(for normalizedDist: CGFloat) -> Double {
        if normalizedDist < 0.45 { return 100 }
        if normalizedDist < 1.25 { return 95 }
        return 90 - Double(normalizedDist)
    }

    private func scale(for normalizedDist: CGFloat) -> CGFloat {
        let falloff = min(normalizedDist, 2.5)
        return max(0.76, selectedScale - falloff * 0.18)
    }

    private func opacity(for normalizedDist: CGFloat) -> CGFloat {
        let falloff = min(normalizedDist, 2.5)
        return max(0.42, 1.0 - falloff * 0.26)
    }

    // MARK: - Selection

    private func selectIndex(_ index: Int) {
        guard assets.indices.contains(index), index != currentIndex else { return }
        haptic.impactOccurred()
        lastDragHapticIndex = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = index
            dragOffset = 0
        }
    }

    /// Index whose thumbnail center is closest to the selection point at the top of the arch.
    private func indexNearestCenter(forDragOffset offset: CGFloat) -> Int {
        guard !assets.isEmpty else { return 0 }
        let fractional = CGFloat(currentIndex) - offset / pitch
        return min(max(Int(round(fractional)), 0), assets.count - 1)
    }

    private func emitDragHapticIfNeeded(for index: Int) {
        guard lastDragHapticIndex != index else { return }
        lastDragHapticIndex = index
        haptic.impactOccurred()
        haptic.prepare()
    }

    // MARK: - Horizontal drag

    private var carouselDrag: some Gesture {
        DragGesture(minimumDistance: dragActivationDistance, coordinateSpace: .local)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    gestureStartOffset = dragOffset
                    lastDragHapticIndex = indexNearestCenter(forDragOffset: dragOffset)
                    haptic.prepare()
                }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    var offset = clampedDragOffset(gestureStartOffset + value.translation.width)
                    rebalanceIndexWhileDragging(proposedOffset: &offset)
                    dragOffset = offset
                    // Keep finger position stable after index rebases mid-drag.
                    gestureStartOffset = dragOffset - value.translation.width
                }
                emitDragHapticIfNeeded(for: currentIndex)
            }
            .onEnded { _ in
                guard isDragging else { return }
                var offset = dragOffset
                rebalanceIndexWhileDragging(proposedOffset: &offset)
                dragOffset = offset
                isDragging = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    dragOffset = 0
                }
                lastDragHapticIndex = nil
            }
    }

    /// Shifts `currentIndex` to whichever thumbnail is nearest center while preserving
    /// on-screen positions (re-bases drag offset so the track does not jump).
    private func rebalanceIndexWhileDragging(proposedOffset: inout CGFloat) {
        let nearest = indexNearestCenter(forDragOffset: proposedOffset)
        guard nearest != currentIndex else { return }
        let delta = nearest - currentIndex
        currentIndex = nearest
        proposedOffset += CGFloat(delta) * pitch
        proposedOffset = clampedDragOffset(proposedOffset)
    }

    private func clampedDragOffset(_ proposed: CGFloat) -> CGFloat {
        guard !assets.isEmpty else { return 0 }
        let maxPositive = CGFloat(currentIndex) * pitch
        let maxNegative = -CGFloat(assets.count - 1 - currentIndex) * pitch
        return min(max(proposed, maxNegative), maxPositive)
    }
}

// MARK: - Single thumbnail in the carousel (peephole styling from PeepholeAlbumCoverTestView)

private enum RotaryCarouselGlow {
    /// Selected carousel thumbnail glow — #52311F.
    static let selectedColor = Color(red: 0x52 / 255, green: 0x31 / 255, blue: 0x1F / 255)
}

struct RotaryThumbCell: View {
    let asset: PHAsset?
    let library: PhotoLibraryManager
    let diameter: CGFloat
    var isCentered: Bool = false

    @State private var thumbnail: UIImage?

    private let palette: PeepholeVisualPalette = .gallery
    private var innerDiameter: CGFloat { diameter - 12 }

    var body: some View {
        Group {
            if let asset, let thumbnail {
                PeepholeAlbumCover(
                    imageSource: .uiImage(thumbnail, cacheKey: asset.localIdentifier),
                    size: diameter,
                    palette: palette,
                    glowIntensity: isCentered ? .carouselSelected : .photoThumbnail,
                    glowColor: isCentered ? RotaryCarouselGlow.selectedColor : nil
                )
            } else {
                peepholeLoadingShell
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { loadThumb() }
        .onChange(of: asset?.localIdentifier) { _ in loadThumb() }
    }

    private var peepholeLoadingShell: some View {
        ZStack {
            PeepholeGlassRimOverlay(
                outerDiameter: diameter,
                innerDiameter: innerDiameter,
                palette: palette
            )
        }
        .frame(width: diameter, height: diameter)
        .peepholeAlbumCircleGlow(
            palette: palette,
            intensity: isCentered ? .carouselSelected : .photoThumbnail,
            glowColor: isCentered ? RotaryCarouselGlow.selectedColor : nil
        )
    }

    private func loadThumb() {
        guard let asset else { thumbnail = nil; return }
        let pixelSize = PhotoLibraryManager.coverThumbnailPixelSize(innerDiameter: innerDiameter)
        if let cached = library.cachedCoverThumbnail(for: asset, size: pixelSize) {
            thumbnail = cached
            return
        }
        library.coverThumbnail(for: asset, size: pixelSize) {
            thumbnail = $0
        }
    }
}
