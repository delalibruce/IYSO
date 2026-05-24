import SwiftUI
import Photos
import UIKit

// Arc-shaped wheel carousel shown below the main photo in PhotoDetailView.
// All album photos scroll along a curved track; the centered item is selected.
struct RotaryNavigationView: View {
    let assets: [PHAsset]
    let library: PhotoLibraryManager
    @Binding var currentIndex: Int

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let baseDiameter: CGFloat = 75
    private let selectedDiameter: CGFloat = 91
    private let itemSpacing: CGFloat = 18
    /// Quadratic drop per pitch unit — controls how steep the arch feels.
    private let archDropPerUnit: CGFloat = 26
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var pitch: CGFloat { baseDiameter + itemSpacing }
    private var selectedScale: CGFloat { selectedDiameter / baseDiameter }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let apexY = selectedDiameter / 2 + 6

            ZStack {
                ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                    let horizontalDist = CGFloat(index - currentIndex) * pitch + dragOffset
                    let normalizedDist = abs(horizontalDist) / pitch
                    let yDrop = archDrop(for: horizontalDist)

                    carouselItem(for: asset, at: index, normalizedDist: normalizedDist)
                        .position(x: centerX + horizontalDist, y: apexY + yDrop)
                }
            }
        }
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(carouselDrag)
    }

    // MARK: - Arch geometry

    private func archDrop(for horizontalDist: CGFloat) -> CGFloat {
        let t = horizontalDist / pitch
        return min(t * t * archDropPerUnit, 72)
    }

    // MARK: - Carousel item

    private func carouselItem(for asset: PHAsset, at index: Int, normalizedDist: CGFloat) -> some View {
        let isCentered = normalizedDist < 0.45

        return Button {
            selectIndex(index)
        } label: {
            RotaryThumbCell(
                asset: asset,
                library: library,
                diameter: baseDiameter
            )
            .scaleEffect(scale(for: normalizedDist))
            .saturation(isCentered ? 1 : 0)
            .opacity(opacity(for: normalizedDist))
            .brightness(isCentered ? 0 : -0.08)
            .zIndex(isCentered ? 1 : 0)
            .animation(isDragging ? nil : .easeInOut(duration: 0.25), value: currentIndex)
        }
        .buttonStyle(.plain)
        .zIndex(100 - normalizedDist)
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
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = index
            dragOffset = 0
        }
    }

    // MARK: - Horizontal drag

    private var carouselDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isDragging { isDragging = true }
                dragOffset = clampedDragOffset(value.translation.width)
            }
            .onEnded { _ in
                isDragging = false
                let delta = -Int(round(dragOffset / pitch))
                let newIndex = min(max(currentIndex + delta, 0), max(assets.count - 1, 0))
                if newIndex != currentIndex {
                    haptic.impactOccurred()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    currentIndex = newIndex
                    dragOffset = 0
                }
            }
    }

    private func clampedDragOffset(_ proposed: CGFloat) -> CGFloat {
        guard !assets.isEmpty else { return 0 }
        let maxPositive = CGFloat(currentIndex) * pitch
        let maxNegative = -CGFloat(assets.count - 1 - currentIndex) * pitch
        return min(max(proposed, maxNegative), maxPositive)
    }
}

// MARK: - Single thumbnail in the carousel

struct RotaryThumbCell: View {
    let asset: PHAsset?
    let library: PhotoLibraryManager
    let diameter: CGFloat
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0x2a/255, green: 0x1a/255, blue: 0x14/255))

            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(Color(white: 0.15))
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear { loadThumb() }
        .onChange(of: asset?.localIdentifier) { _ in loadThumb() }
    }

    private func loadThumb() {
        guard let asset else { thumbnail = nil; return }
        let scale = UIScreen.main.scale
        library.thumbnail(for: asset, size: CGSize(width: diameter * scale, height: diameter * scale)) {
            thumbnail = $0
        }
    }
}
