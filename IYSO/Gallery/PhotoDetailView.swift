import SwiftUI
import Photos
import UIKit

private struct PhotoFileNameEditSheetItem: Identifiable {
    let id: String
    let asset: PHAsset
}

private enum PhotoDetailLayout {
    static let mainPhotoDiameter: CGFloat = 327
    /// Gap from header row to top of main photo circle.
    static let headerToPhotoSpacing: CGFloat = 48
    /// Gap from bottom of main photo circle to top of thumbnail carousel.
    static let photoToCarouselSpacing: CGFloat = 80
}

private enum PhotoPullDownDismiss {
    static let distanceThreshold: CGFloat = 90
    /// Drag distance that fully reveals the gallery and lands on the grid slot.
    static let transitionDistance: CGFloat = 200
    static let settleDuration: TimeInterval = 0.16
    static let gridPhotoDiameter: CGFloat = 118
}

// Level 3 — full-screen circular photo with rotary dial navigation.
struct PhotoDetailView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    @ObservedObject var library: PhotoLibraryManager
    let gridCellFrames: [String: CGRect]
    @Binding var concealedGridAssetID: String?
    let onDismiss: () -> Void

    @EnvironmentObject private var appState: AppState

    @State private var currentIndex: Int
    @State private var fullResImage: UIImage?
    @State private var lowResImage: UIImage?
    @State private var photoDragOffset: CGSize = .zero
    @State private var isPhotoDragActive = false
    @State private var isPullDismissAnimating = false
    @State private var heroSettleProgress: CGFloat = 0
    @State private var layoutPhotoFrame: CGRect = .zero
    @State private var deletedAssetIDs: Set<String> = []
    @State private var shareSheetPayload: ShareSheetPayload?
    @State private var showDeleteConfirm = false
    @State private var fileNameEditingItem: PhotoFileNameEditSheetItem?
    @State private var carouselSwipeExclusionFrame: CGRect?
    @State private var isCarouselDragging = false
    @State private var thumbRequestID: PHImageRequestID = PHInvalidImageRequestID
    @State private var detailRequestID: PHImageRequestID = PHInvalidImageRequestID

    init(
        assets: [PHAsset],
        initialIndex: Int,
        library: PhotoLibraryManager,
        gridCellFrames: [String: CGRect],
        concealedGridAssetID: Binding<String?>,
        onDismiss: @escaping () -> Void
    ) {
        self.assets = assets
        self.initialIndex = initialIndex
        _library = ObservedObject(wrappedValue: library)
        self.gridCellFrames = gridCellFrames
        _concealedGridAssetID = concealedGridAssetID
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    private var visibleAssets: [PHAsset] {
        assets.filter { !deletedAssetIDs.contains($0.localIdentifier) }
    }

    private var currentAsset: PHAsset? {
        visibleAssets.indices.contains(currentIndex) ? visibleAssets[currentIndex] : nil
    }

    private var photoName: String {
        guard let asset = currentAsset else { return "" }
        return library.photoDisplayName(for: asset)
    }

    private var pullDownProgress: CGFloat {
        min(max(photoDragOffset.height, 0) / PhotoPullDownDismiss.transitionDistance, 1)
    }

    private var heroProgress: CGFloat {
        min(1, max(pullDownProgress, heroSettleProgress))
    }

    private var isHeroFlying: Bool {
        heroProgress > 0.001 || isPullDismissAnimating
    }

    private var pullDownChromeOpacity: Double {
        Double(1 - heroProgress * 0.96)
    }

    private var detailScrimOpacity: Double {
        Double(1 - heroProgress)
    }

    private var targetGridFrame: CGRect? {
        guard let id = currentAsset?.localIdentifier else { return nil }
        let frame = gridCellFrames[id]
        guard let frame, frame.width > 1, frame.height > 1 else { return nil }
        return frame
    }

    var body: some View {
        SDCardScreenContainer { topPadding, bottomSafeInset in
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground
                    .opacity(detailScrimOpacity)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topPadding: topPadding)
                        .opacity(pullDownChromeOpacity)
                    Spacer().frame(height: PhotoDetailLayout.headerToPhotoSpacing)
                    layoutPhotoPlaceholder
                    Spacer().frame(height: PhotoDetailLayout.photoToCarouselSpacing)
                    RotaryNavigationView(
                        assets: visibleAssets,
                        library: library,
                        currentIndex: $currentIndex,
                        isDragging: $isCarouselDragging
                    )
                    .opacity(pullDownChromeOpacity)
                    .allowsHitTesting(!isPhotoDragActive && heroProgress < 0.12)
                    .memoryFlowSwipeBackExclusionFrame(in: .named("photoDetail"))
                    Spacer(minLength: 0)
                }

                photoDetailBottomBar(bottomSafeInset: bottomSafeInset)
                    .opacity(pullDownChromeOpacity)
                    .allowsHitTesting(!isPhotoDragActive && heroProgress < 0.12)

                if isHeroFlying, let heroRect = heroPhotoRect(progress: heroProgress) {
                    detailPeepholePhoto(diameter: heroRect.width)
                        .position(x: heroRect.midX, y: heroRect.midY)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "photoDetail")
            .onPreferenceChange(MemoryFlowSwipeBackExclusionFrameKey.self) { frame in
                carouselSwipeExclusionFrame = frame
            }
            .memoryFlowSwipeToGoBack(
                excludesStartLocation: { point in
                    if isPhotoDragActive || heroProgress > 0.05 { return true }
                    guard let frame = carouselSwipeExclusionFrame else { return false }
                    return frame.insetBy(dx: -16, dy: -12).contains(point)
                },
                onBack: { beginHeroDismiss() }
            )
            .navigationBarHidden(true)
            .onChange(of: currentIndex) { _ in
                concealedGridAssetID = currentAsset?.localIdentifier
                if !isCarouselDragging {
                    loadImages()
                }
            }
            .onChange(of: isCarouselDragging) { dragging in
                guard !dragging else { return }
                concealedGridAssetID = currentAsset?.localIdentifier
                loadImages()
            }
            .onAppear {
                appState.isPhotoDetailPresented = true
                concealedGridAssetID = currentAsset?.localIdentifier
                loadImages()
            }
            .onDisappear {
                appState.isPhotoDetailPresented = false
                cancelImageRequests()
            }
            .memoryFlowDeleteConfirmation("Delete Photo?", isPresented: $showDeleteConfirm) {
                deleteCurrentPhoto()
            }
            .sheet(item: $shareSheetPayload) { payload in
                ShareSheet(items: payload.items)
            }
            .sheet(item: $fileNameEditingItem) { item in
                PhotoFileNameEditView(asset: item.asset, library: library)
            }
        }
    }

    // MARK: - Header

    private func header(topPadding: CGFloat) -> some View {
        ZStack {
            Button {
                guard let asset = currentAsset else { return }
                fileNameEditingItem = PhotoFileNameEditSheetItem(
                    id: asset.localIdentifier,
                    asset: asset
                )
            } label: {
                Text(photoName)
                    .font(.system(size: 17.7, weight: .regular))
                    .foregroundColor(Color(white: 0xd4/255))
                    .tracking(-0.885)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 56)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(currentAsset == nil)

            HStack {
                Button(action: { beginHeroDismiss() }) {
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
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            MemoryFlowHeaderScrim()
        }
        .animation(.easeInOut(duration: 0.2), value: photoName)
    }

    // MARK: - Main photo

    /// Keeps layout spacing and reports the resting frame for hero interpolation.
    private var layoutPhotoPlaceholder: some View {
        mainPhotoCircle
            .opacity(isHeroFlying ? 0 : 1)
            .reportsPhotoLayoutFrame()
            .onPhotoLayoutFrameChange { layoutPhotoFrame = $0 }
            .highPriorityGesture(pullDownDismiss)
    }

    private var mainPhotoCircle: some View {
        detailPeepholePhoto(diameter: PhotoDetailLayout.mainPhotoDiameter)
            .animation(isCarouselDragging ? nil : .easeInOut(duration: 0.2), value: currentIndex)
    }

    /// Large detail hero — original photo in a circle with glow/rim only (no bulge, vignette, or lens).
    @ViewBuilder
    private func detailPeepholePhoto(diameter: CGFloat) -> some View {
        let palette: PeepholeVisualPalette = .gallery
        let innerDiameter = max(diameter - 12, 1)

        ZStack {
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

            PeepholeGlassRimOverlay(
                outerDiameter: diameter,
                innerDiameter: innerDiameter,
                palette: palette
            )
        }
        .frame(width: diameter, height: diameter)
        .peepholeAlbumCircleGlow(palette: palette, intensity: .albumCover)
    }

    private func heroPhotoRect(progress: CGFloat) -> CGRect? {
        let start = layoutPhotoFrame
        guard start.width > 1, start.height > 1 else { return nil }

        let eased = smoothstep(progress)

        if let rawTarget = targetGridFrame {
            let target = normalizedGridCircleFrame(rawTarget)
            var rect = CGRect(
                x: start.minX + (target.minX - start.minX) * eased,
                y: start.minY + (target.minY - start.minY) * eased,
                width: start.width + (target.width - start.width) * eased,
                height: start.height + (target.height - start.height) * eased
            )
            if isPhotoDragActive, progress < 1 {
                rect.origin.x += photoDragOffset.width * (1 - eased) * 0.3
            }
            return rect
        }

        let scale = 1 - eased * 0.7
        let size = start.width * scale
        return CGRect(
            x: start.midX - size / 2 + photoDragOffset.width * (1 - eased) * 0.3,
            y: start.midY - size / 2 + photoDragOffset.height * (1 - eased * 0.5),
            width: size,
            height: size
        )
    }

    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// Grid preference frames include the filename label; align to the circular thumbnail only.
    private func normalizedGridCircleFrame(_ cellFrame: CGRect) -> CGRect {
        let d = PhotoPullDownDismiss.gridPhotoDiameter
        return CGRect(
            x: cellFrame.midX - d / 2,
            y: cellFrame.minY,
            width: d,
            height: d
        )
    }

    // MARK: - Pull-down dismiss gesture

    private var pullDownDismiss: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                guard !isPullDismissAnimating else { return }

                let vertical = value.translation.height
                let horizontal = value.translation.width

                if !isPhotoDragActive {
                    guard vertical > 0, vertical > abs(horizontal) * 0.65 else { return }
                    isPhotoDragActive = true
                }

                photoDragOffset = CGSize(
                    width: horizontal * 0.35,
                    height: max(vertical, 0)
                )
            }
            .onEnded { value in
                guard !isPullDismissAnimating else { return }

                isPhotoDragActive = false
                let dragY = max(photoDragOffset.height, 0)
                let predictedY = value.predictedEndTranslation.height
                let flingDown = value.velocity.height > 750
                let shouldDismiss = dragY > PhotoPullDownDismiss.distanceThreshold
                    || predictedY > PhotoPullDownDismiss.transitionDistance * 1.4
                    || flingDown

                if shouldDismiss {
                    beginHeroDismiss()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        photoDragOffset = .zero
                    }
                }
            }
    }

    private func beginHeroDismiss() {
        guard !isPullDismissAnimating else { return }
        isPullDismissAnimating = true
        isPhotoDragActive = false

        let startProgress = heroProgress

        withAnimation(.easeOut(duration: PhotoPullDownDismiss.settleDuration)) {
            heroSettleProgress = 1
            photoDragOffset = .zero
        }

        let remaining = PhotoPullDownDismiss.settleDuration * Double(1 - startProgress)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(remaining, 0.06)) {
            onDismiss()
        }
    }

    // MARK: - Bottom bar

    private func photoDetailBottomBar(bottomSafeInset: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 0) {
                MemoryFlowGlassIconButton(
                    systemName: "square.and.arrow.up",
                    isEnabled: currentAsset != nil,
                    action: shareCurrentPhoto
                )

                Spacer(minLength: 12)

                BottomToggle(
                    activeTab: $appState.activeTab,
                    onCameraRequested: handleCameraRequestedFromDetail
                )

                Spacer(minLength: 12)

                MemoryFlowGlassIconButton(
                    systemName: "trash",
                    isEnabled: currentAsset != nil
                ) {
                    guard currentAsset != nil else { return }
                    showDeleteConfirm = true
                }
            }
            .padding(.horizontal, 24)
            .alignedToBottomToggle(safeAreaBottom: bottomSafeInset)
            .padding(.bottom, BottomToggleLayout.detailFlowExtraLift)
        }
    }

    // MARK: - Actions

    private func shareCurrentPhoto() {
        guard let asset = currentAsset else { return }
        library.exportAssetFileURL(for: asset) { fileURL in
            if let fileURL {
                shareSheetPayload = ShareSheetPayload(items: [fileURL])
                return
            }

            // Fallback keeps share available if Photos resource export is unavailable.
            library.fullResImage(for: asset) { image in
                guard let image else { return }
                shareSheetPayload = ShareSheetPayload(items: [image])
            }
        }
    }

    private func deleteCurrentPhoto() {
        guard let asset = currentAsset else { return }
        let deletingIndex = currentIndex
        deletedAssetIDs.insert(asset.localIdentifier)
        library.deleteAsset(asset) { _ in }

        let remaining = visibleAssets
        if remaining.isEmpty {
            beginHeroDismiss()
        } else if deletingIndex >= remaining.count {
            currentIndex = remaining.count - 1
            concealedGridAssetID = currentAsset?.localIdentifier
        } else {
            concealedGridAssetID = currentAsset?.localIdentifier
        }
    }

    // MARK: - Image loading

    private func loadImages() {
        cancelImageRequests()
        lowResImage = nil
        fullResImage = nil
        guard let asset = currentAsset else { return }
        let assetID = asset.localIdentifier
        let px = PhotoDetailLayout.mainPhotoDiameter * 2
        thumbRequestID = library.thumbnail(for: asset, size: CGSize(width: px, height: px)) { img in
            guard self.currentAsset?.localIdentifier == assetID else { return }
            if self.fullResImage == nil { self.lowResImage = img }
        }
        detailRequestID = library.detailImage(for: asset, diameter: PhotoDetailLayout.mainPhotoDiameter) { img in
            guard self.currentAsset?.localIdentifier == assetID else { return }
            self.fullResImage = img
        }
    }

    private func cancelImageRequests() {
        library.cancelImageRequest(thumbRequestID)
        library.cancelImageRequest(detailRequestID)
        thumbRequestID = PHInvalidImageRequestID
        detailRequestID = PHInvalidImageRequestID
    }

    /// Mirrors root toggle behavior so camera entry from detail still respects IYSO Mode gating.
    private func handleCameraRequestedFromDetail() {
        if appState.isIYSOMode {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.activeTab = .camera
            }
        } else {
            appState.showEnterIYSOModeSheet = true
        }
    }
}
