import SwiftUI
import Photos
import UIKit

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private enum PhotoDetailLayout {
    static let mainPhotoDiameter: CGFloat = 327
    /// Gap from header row to top of main photo circle.
    static let headerToPhotoSpacing: CGFloat = 48
}

// Level 3 — full-screen circular photo with rotary dial navigation.
struct PhotoDetailView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    let library: PhotoLibraryManager

    @State private var currentIndex: Int
    @State private var fullResImage: UIImage?
    @State private var lowResImage: UIImage?
    @State private var photoYOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    init(assets: [PHAsset], initialIndex: Int, library: PhotoLibraryManager) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.library = library
        _currentIndex = State(initialValue: initialIndex)
    }

    private var currentAsset: PHAsset? { assets.indices.contains(currentIndex) ? assets[currentIndex] : nil }

    private var photoName: String {
        guard let asset = currentAsset else { return "" }
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename ?? ""
    }

    var body: some View {
        SDCardScreenContainer { topPadding in
            ZStack(alignment: .bottom) {
                Color(red: 0x17/255, green: 0x0e/255, blue: 0x0b/255).ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topPadding: topPadding)
                    Spacer().frame(height: PhotoDetailLayout.headerToPhotoSpacing)
                    mainPhotoCircle
                        .offset(y: photoYOffset)
                        .gesture(pullDownDismiss)
                    Spacer(minLength: 0)
                }

                rotaryPanel
            }
            .memoryFlowSwipeToGoBack { dismiss() }
            .navigationBarHidden(true)
            .background(DisableSystemPopGesture())
            .onChange(of: currentIndex) { _ in loadImages() }
            .onAppear { loadImages() }
        }
    }

    // MARK: - Header

    private func header(topPadding: CGFloat) -> some View {
        ZStack {
            Text(photoName)
                .font(.system(size: 17.7, weight: .regular))
                .foregroundColor(Color(white: 0xd4/255))
                .tracking(-0.885)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 56)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .animation(.easeInOut(duration: 0.2), value: photoName)
    }

    // MARK: - Main photo circle (plain photo; outer glow + glass rim only)

    private var mainPhotoCircle: some View {
        let diameter = PhotoDetailLayout.mainPhotoDiameter
        let innerDiameter = diameter - 12

        return ZStack {
            Group {
                if let img = fullResImage ?? lowResImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: innerDiameter, height: innerDiameter)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: innerDiameter, height: innerDiameter)
                }
            }
            .frame(width: diameter, height: diameter)
            .peepholeAlbumCircleGlow(palette: .gallery)

            PeepholeGlassRimOverlay(
                outerDiameter: diameter,
                innerDiameter: innerDiameter,
                palette: .gallery
            )
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.2), value: currentIndex)
    }

    // MARK: - Pull-down dismiss gesture

    private var pullDownDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    photoYOffset = value.translation.height
                }
            }
            .onEnded { value in
                if photoYOffset > 150 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        photoYOffset = UIScreen.main.bounds.height
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        photoYOffset = 0
                    }
                }
            }
    }

    // MARK: - Rotary panel

    private var rotaryPanel: some View {
        VStack(spacing: 0) {
            RotaryNavigationView(
                assets: assets,
                library: library,
                currentIndex: $currentIndex
            )
            Spacer()
        }
        .frame(height: 282)
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 0x2a/255, green: 0x1a/255, blue: 0x14/255)
                .clipShape(TopRoundedRectangle(radius: 60))
        )
        .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: -4)
    }

    // MARK: - Image loading

    private func loadImages() {
        fullResImage = nil
        guard let asset = currentAsset else { return }
        let px = PhotoDetailLayout.mainPhotoDiameter * 2
        library.thumbnail(for: asset, size: CGSize(width: px, height: px)) { img in
            if self.fullResImage == nil { self.lowResImage = img }
        }
        library.fullResImage(for: asset) { img in
            self.fullResImage = img
        }
    }
}
