import SwiftUI
import Photos
import UIKit

// Preference key for collecting photo cell frames (used by swipe-select)
private struct PhotoGridFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

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
    @State private var sharingImages: [UIImage] = []
    @State private var isShareSheetPresented = false

    // Confirmation for delete
    @State private var assetPendingDelete: PHAsset? = nil
    @State private var showDeleteConfirm = false

    // Selection mode
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var swipeSelectDirection: Bool? = nil   // true = selecting, false = deselecting
    @State private var swipeSelectTouched: Set<String> = []
    @State private var showDeleteSelectedConfirm = false

    private var visibleAssets: [PHAsset] {
        assets.filter { !deletedAssetIDs.contains($0.localIdentifier) }
    }

    var body: some View {
        SDCardScreenContainer { topPadding in
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    memoryFlowHeader(topPadding: topPadding)
                    photoScrollView
                }

                if isSelecting { selectionBottomBar }
            }
            .memoryFlowSwipeToGoBack { dismiss() }
            .navigationBarHidden(true)
            .background(DisableSystemPopGesture())
            .onChange(of: isSelecting) { selecting in
                appState.isAlbumSelecting = selecting
                if !selecting { selectedIDs = [] }
            }
            .onDisappear { appState.isAlbumSelecting = false }
            .confirmationDialog("Delete Photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let asset = assetPendingDelete { deletePhoto(asset) }
                }
            }
            .confirmationDialog("Delete \(selectedIDs.count) photo\(selectedIDs.count == 1 ? "" : "s")?",
                                isPresented: $showDeleteSelectedConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteSelectedPhotos() }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(items: sharingImages)
            }
        }
    }

    // MARK: - Header

    private func memoryFlowHeader(topPadding: CGFloat) -> some View {
        MemoryFlowHeader(
            title: isSelecting
                ? (selectedIDs.isEmpty ? "Select Photos" : "\(selectedIDs.count) selected")
                : albumTitle,
            subtitle: PhotoLibraryManager.itemCountLabel(count: visibleAssets.count),
            topPadding: topPadding,
            hidesCenterTitle: !isSelecting
        ) {
            Group {
                if isSelecting {
                    Button("Cancel") {
                        isSelecting = false
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                } else {
                    MemoryFlowBackHeaderGroup(title: albumTitle, action: { dismiss() })
                }
            }
        } trailing: {
            Group {
                if isSelecting {
                    Button("All") {
                        selectedIDs = Set(visibleAssets.map { $0.localIdentifier })
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                } else {
                    Button("Select") { isSelecting = true }
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Photo grid

    private var photoScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            photoGrid
                .padding(.top, 10)
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
            NavigationLink {
                PhotoDetailView(assets: visibleAssets, initialIndex: index, library: library)
            } label: {
                cell
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func photoCell(asset: PHAsset) -> some View {
        let isSelected = selectedIDs.contains(asset.localIdentifier)
        ZStack(alignment: .topTrailing) {
            CircularPhotoCell(asset: asset, library: library, diameter: 118)
            if isSelecting {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Color(red: 0x7f/255, green: 0x68/255, blue: 0x60/255)
                              : Color.black.opacity(0.45))
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - Selection bottom bar

    private var selectionBottomBar: some View {
        VStack {
            Spacer()
            HStack {
                Button {
                    guard !selectedIDs.isEmpty else { return }
                    showDeleteSelectedConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(selectedIDs.isEmpty ? Color(white: 0.4) : .white)
                        .frame(width: 50, height: 50)
                }
                Spacer()
                Button {
                    shareSelectedPhotos()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(selectedIDs.isEmpty ? Color(white: 0.4) : .white)
                        .frame(width: 50, height: 50)
                }
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .background(
                PeepholeVisualPalette.memoryFlowBackground
                    .ignoresSafeArea(edges: .bottom)
            )
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

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
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
            sharingImages = [image]
            isShareSheetPresented = true
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
            sharingImages = images
            isShareSheetPresented = true
        }
    }
}

