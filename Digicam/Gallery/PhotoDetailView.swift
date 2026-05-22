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

    private var headerDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM.dd.yyyy"
        return currentAsset?.creationDate.map { fmt.string(from: $0) } ?? ""
    }

    private var photoName: String {
        guard let asset = currentAsset else { return "" }
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename ?? ""
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0x17/255, green: 0x0e/255, blue: 0x0b/255).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
            }

            mainPhotoCircle
                .padding(.bottom, 282 + 20)
                .offset(y: photoYOffset)
                .gesture(pullDownDismiss)

            rotaryPanel
        }
        .navigationBarHidden(true)
        .onChange(of: currentIndex) { _ in loadImages() }
        .onAppear { loadImages() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
            }
            Text(headerDate)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.white)
                .tracking(-1.2)
            Spacer()
        }
        .padding(.leading, 13)
        .padding(.top, 64)
    }

    // MARK: - Main photo circle (~327pt diameter)

    private var mainPhotoCircle: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0x2a/255, green: 0x1a/255, blue: 0x14/255))
                .frame(width: 327, height: 327)

            if let img = fullResImage ?? lowResImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 295, height: 295)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(white: 0.1))
                    .frame(width: 295, height: 295)
            }
        }
        .overlay(
            Text(photoName)
                .font(.system(size: 17.7, weight: .regular))
                .foregroundColor(Color(white: 0xd4/255))
                .tracking(-0.885)
                .frame(width: 327)
                .multilineTextAlignment(.center)
                .offset(y: 327/2 + 16),
            alignment: .center
        )
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
        library.thumbnail(for: asset, size: CGSize(width: 327 * 2, height: 327 * 2)) { img in
            if self.fullResImage == nil { self.lowResImage = img }
        }
        library.fullResImage(for: asset) { img in
            self.fullResImage = img
        }
    }
}
