import SwiftUI
import Photos
import UIKit

// Rotary dial strip shown at the bottom of PhotoDetailView.
// Five circular thumbnails fanned out in a perspective arc.
// Dragging clockwise = next, CCW = previous. Tapping a side bubble navigates directly.
struct RotaryNavigationView: View {
    let assets: [PHAsset]
    let library: PhotoLibraryManager
    @Binding var currentIndex: Int

    @State private var accumulatedAngle: Double = 0
    @State private var previousAngle: Double? = nil

    private let advanceThreshold: Double = 0.35 // radians (~20°)
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0x64/255, green: 0x50/255, blue: 0x47/255))
                .frame(width: 75, height: 5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)

            GeometryReader { geo in
                let cx = geo.size.width / 2
                let cy: CGFloat = 50

                ZStack {
                    fanThumbnail(offset: -174, verticalOffset: 97, opacity: 0.5, relIndex: -2, cx: cx, cy: cy)
                    fanThumbnail(offset: -95,  verticalOffset: 60,  opacity: 0.75, relIndex: -1, cx: cx, cy: cy)
                    fanThumbnail(offset: 95,   verticalOffset: 60,  opacity: 0.75, relIndex: 1,  cx: cx, cy: cy)
                    fanThumbnail(offset: 174,  verticalOffset: 97,  opacity: 0.5,  relIndex: 2,  cx: cx, cy: cy)
                    fanThumbnail(offset: 0, verticalOffset: 34, opacity: 1.0, relIndex: 0, cx: cx, cy: cy)
                }
            }
            .frame(height: 200)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .gesture(rotaryDrag)
    }

    // MARK: - Fan thumbnail

    private func fanThumbnail(
        offset: CGFloat,
        verticalOffset: CGFloat,
        opacity: Double,
        relIndex: Int,
        cx: CGFloat,
        cy: CGFloat
    ) -> some View {
        let diameter: CGFloat = relIndex == 0 ? 91 : 75
        let assetIndex = currentIndex + relIndex
        let valid = assets.indices.contains(assetIndex)

        return RotaryThumbCell(
            asset: valid ? assets[assetIndex] : nil,
            library: library,
            diameter: diameter
        )
        .opacity(valid ? opacity : 0)
        .position(x: cx + offset, y: verticalOffset + diameter / 2)
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
        .onTapGesture {
            guard relIndex != 0, valid else { return }
            advance(by: relIndex)
        }
    }

    // MARK: - Circular drag gesture

    private var rotaryDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: 0)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)

                guard let prev = previousAngle else {
                    previousAngle = angle
                    return
                }

                var delta = angle - prev
                if delta > .pi  { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }

                accumulatedAngle -= delta
                previousAngle = angle

                if accumulatedAngle >= advanceThreshold {
                    advance(by: 1)
                    accumulatedAngle = 0
                } else if accumulatedAngle <= -advanceThreshold {
                    advance(by: -1)
                    accumulatedAngle = 0
                }
            }
            .onEnded { _ in
                previousAngle = nil
                accumulatedAngle = 0
            }
    }

    // advance(by:) is the single source of truth for both navigation and haptics.
    private func advance(by delta: Int) {
        let next = currentIndex + delta
        guard assets.indices.contains(next) else { return }
        haptic.impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) { currentIndex = next }
    }
}

// MARK: - Single thumbnail in the rotary fan

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
