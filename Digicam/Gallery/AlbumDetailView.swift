import SwiftUI
import Photos
import UIKit

// Level 2 — all photos in album as a 3-column grid, most recent first.
struct AlbumDetailView: View {
    let assets: [PHAsset]
    let albumTitle: String
    let albumID: String
    let library: PhotoLibraryManager

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Photo deletion (local filter until library reloads)
    @State private var deletedAssetIDs: Set<String> = []

    // Photo to share (triggers sheet)
    @State private var shareSheetPayload: ShareSheetPayload?

    // Confirmation for delete
    @State private var assetPendingDelete: PHAsset? = nil
    @State private var showDeleteConfirm = false

    // Selection mode
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var presentedPhotoIndex: Int?
    @State private var concealedGridAssetID: String?
    @State private var swipeSelectDirection: Bool? = nil   // true = selecting, false = deselecting
    @State private var swipeSelectTouched: Set<String> = []
    @State private var showDeleteSelectedConfirm = false

    @State private var memoryFlowHeaderLayoutHeight: CGFloat = 0

    private var visibleAssets: [PHAsset] {
        assets.filter { !deletedAssetIDs.contains($0.localIdentifier) }
    }

    var body: some View {
        SDCardScreenContainer { topPadding, _ in
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                ZStack(alignment: .top) {
                    photoScrollView(topPadding: topPadding)
                    memoryFlowHeader(topPadding: topPadding)
                        .zIndex(2)
                }
                .onPreferenceChange(MemoryFlowHeaderLayoutHeightKey.self) {
                    memoryFlowHeaderLayoutHeight = $0
                }
                .memoryFlowSwipeToGoBack {
                    if isSelecting {
                        exitSelectionMode()
                    } else {
                        dismiss()
                    }
                }

                if isSelecting { selectionBottomBar }

                if let presentedPhotoIndex {
                    PhotoDetailView(
                        assets: visibleAssets,
                        initialIndex: presentedPhotoIndex,
                        library: library,
                        gridCellFrames: cellFrames,
                        concealedGridAssetID: $concealedGridAssetID,
                        onDismiss: closePhotoDetail
                    )
                    .zIndex(1)
                }
            }
            .navigationBarHidden(true)
            .background(DisableSystemPopGesture())
            .onChange(of: isSelecting) { selecting in
                appState.isAlbumSelecting = selecting
                if !selecting { selectedIDs = [] }
            }
            .onDisappear { appState.isAlbumSelecting = false }
            .memoryFlowDeleteConfirmation("Delete Photo?", isPresented: $showDeleteConfirm) {
                if let asset = assetPendingDelete { deletePhoto(asset) }
            }
            .memoryFlowDeleteConfirmation(
                "Delete \(selectedIDs.count) photo\(selectedIDs.count == 1 ? "" : "s")?",
                isPresented: $showDeleteSelectedConfirm
            ) {
                deleteSelectedPhotos()
            }
            .sheet(item: $shareSheetPayload) { payload in
                ShareSheet(items: payload.items)
            }
        }
    }

    // MARK: - Header

    private func memoryFlowHeader(topPadding: CGFloat) -> some View {
        MemoryFlowHeader(
            title: albumTitle,
            subtitle: PhotoLibraryManager.itemCountLabel(count: visibleAssets.count),
            topPadding: topPadding,
            hidesCenterTitle: true
        ) {
            Group {
                if isSelecting {
                    Text("Select Photos")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                        .tracking(-1.2)
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    MemoryFlowBackHeaderGroup(title: albumTitle, action: { dismiss() })
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSelecting)
        } trailing: {
            selectionHeaderTrailing
        }
    }

    @ViewBuilder
    private var selectionHeaderTrailing: some View {
        HStack(spacing: 16) {
            if isSelecting {
                MemoryFlowToolbarTextButton(title: "Select All", action: toggleSelectAll)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            if isSelecting {
                MemoryFlowToolbarIconButton(systemName: "xmark", action: exitSelectionMode)
                    .accessibilityLabel("Done selecting")
            } else {
                MemoryFlowToolbarTextButton(title: "Select", action: enterSelectionMode)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSelecting)
    }

    // MARK: - Photo grid

    private func photoScrollView(topPadding: CGFloat) -> some View {
        let headerScrollInset = max(memoryFlowHeaderLayoutHeight, topPadding + 72)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear.frame(height: headerScrollInset)
                photoGrid
                    .padding(.top, 10)
            }
            .padding(.bottom, isSelecting ? 160 : 120)
        }
        .simultaneousGesture(swipeSelectGesture)
        .onPreferenceChange(PhotoGridFrameKey.self) { cellFrames = $0 }
    }

    private var photoGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(118), spacing: 7), count: 3)
        return LazyVGrid(columns: columns, spacing: 17) {
            ForEach(Array(visibleAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                gridCell(for: asset, at: index)
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 12)
    }

    @ViewBuilder
    private func gridCell(for asset: PHAsset, at index: Int) -> some View {
        let cell = photoCell(asset: asset)
            .contextMenu {
                Button { sharePhoto(asset) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    assetPendingDelete = asset
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    library.setAlbumCover(albumID: albumID, assetLocalID: asset.localIdentifier)
                } label: {
                    Label("Set as Album Cover", systemImage: "photo")
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: PhotoGridFrameKey.self,
                        value: [asset.localIdentifier: geo.frame(in: .global)]
                    )
                }
            )

        if isSelecting {
            cell.onTapGesture { toggleSelection(asset.localIdentifier) }
        } else {
            cell
                .opacity(concealedGridAssetID == asset.localIdentifier ? 0 : 1)
                .contentShape(Rectangle())
                .onTapGesture { openPhotoDetail(at: index, assetID: asset.localIdentifier) }
        }
    }

    @ViewBuilder
    private func photoCell(asset: PHAsset) -> some View {
        let isSelected = selectedIDs.contains(asset.localIdentifier)
        ZStack(alignment: .topTrailing) {
            CircularPhotoCell(
                asset: asset,
                library: library,
                diameter: 118,
                showPeepholeEffect: true
            )
            if isSelecting, isSelected {
                ZStack {
                    Circle()
                        .fill(Color(red: 0x67/255, green: 0x3f/255, blue: 0x2d/255))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 9)
                .padding(.trailing, 6)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Selection bottom bar

    private var selectionBottomBar: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 0) {
                MemoryFlowGlassIconButton(
                    systemName: "square.and.arrow.up",
                    isEnabled: !selectedIDs.isEmpty,
                    action: shareSelectedPhotos
                )

                Spacer(minLength: 12)

                MemoryFlowSelectionCountPill(count: selectedIDs.count)
                    .animation(.easeInOut(duration: 0.15), value: selectedIDs.count)

                Spacer(minLength: 12)

                MemoryFlowGlassIconButton(
                    systemName: "trash",
                    isEnabled: !selectedIDs.isEmpty
                ) {
                    guard !selectedIDs.isEmpty else { return }
                    showDeleteSelectedConfirm = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Swipe-select gesture

    private var swipeSelectGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                guard isSelecting else { return }
                let loc = value.location
                for (assetID, frame) in cellFrames {
                    guard frame.contains(loc), !swipeSelectTouched.contains(assetID) else { continue }
                    swipeSelectTouched.insert(assetID)
                    if swipeSelectDirection == nil {
                        swipeSelectDirection = !selectedIDs.contains(assetID)
                    }
                    if swipeSelectDirection == true { selectedIDs.insert(assetID) }
                    else { selectedIDs.remove(assetID) }
                }
            }
            .onEnded { _ in
                swipeSelectDirection = nil
                swipeSelectTouched = []
            }
    }

    // MARK: - Photo detail presentation

    private func openPhotoDetail(at index: Int, assetID: String) {
        concealedGridAssetID = assetID
        presentedPhotoIndex = index
    }

    private func closePhotoDetail() {
        presentedPhotoIndex = nil
        concealedGridAssetID = nil
    }

    // MARK: - Actions

    private func enterSelectionMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelecting = true
        }
    }

    private func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelecting = false
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }

    private var allVisiblePhotosSelected: Bool {
        let visible = visibleAssets
        guard !visible.isEmpty else { return false }
        return visible.allSatisfy { selectedIDs.contains($0.localIdentifier) }
    }

    private func toggleSelectAll() {
        if allVisiblePhotosSelected {
            selectedIDs = []
        } else {
            selectedIDs = Set(visibleAssets.map(\.localIdentifier))
        }
    }

    private func deletePhoto(_ asset: PHAsset) {
        deletedAssetIDs.insert(asset.localIdentifier)
        library.deleteAsset(asset) { _ in }
    }

    private func deleteSelectedPhotos() {
        let toDelete = visibleAssets.filter { selectedIDs.contains($0.localIdentifier) }
        toDelete.forEach { deletedAssetIDs.insert($0.localIdentifier) }
        selectedIDs = []
        toDelete.forEach { library.deleteAsset($0) { _ in } }
    }

    private func sharePhoto(_ asset: PHAsset) {
        library.fullResImage(for: asset) { image in
            guard let image else { return }
            shareSheetPayload = ShareSheetPayload(items: [image])
        }
    }

    private func shareSelectedPhotos() {
        let toShare = visibleAssets.filter { selectedIDs.contains($0.localIdentifier) }
        var images: [UIImage] = []
        let group = DispatchGroup()
        toShare.forEach { asset in
            group.enter()
            library.fullResImage(for: asset) { img in
                if let img { images.append(img) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard !images.isEmpty else { return }
            shareSheetPayload = ShareSheetPayload(items: images)
        }
    }
}

