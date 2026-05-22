import SwiftUI
import Photos
import UIKit

private struct AlbumFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// Level 1 — date album grid ("iyso memory card").
struct GalleryRootView: View {
    @ObservedObject var library: PhotoLibraryManager

    @State private var navigationPath = NavigationPath()

    // Drag-to-combine state
    @State private var draggingAlbumID: String? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dropTargetID: String? = nil
    @State private var albumCellFrames: [String: CGRect] = [:]

    // Album context menu (shown after long-press with no drag)
    @State private var contextMenuAlbum: DateAlbum? = nil
    @State private var editingAlbum: DateAlbum? = nil
    @State private var albumPendingDelete: DateAlbum? = nil
    @State private var showDeleteAlbumConfirm = false
    @State private var sharingImages: [UIImage] = []
    @State private var isShareSheetPresented = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(red: 0x1e/255, green: 0x13/255, blue: 0x0f/255).ignoresSafeArea()

                switch library.authorizationStatus {
                case .authorized, .limited:
                    albumContent
                case .denied, .restricted:
                    permissionDenied
                default:
                    Color.clear
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { albumID in
                if let album = library.albums.first(where: { $0.id == albumID }) {
                    AlbumDetailView(
                        assets: album.assets,
                        albumTitle: album.displayDate,
                        albumID: albumID,
                        library: library
                    )
                }
            }
        }
        .onAppear { library.requestAccessAndLoad() }
        // Context menu for album cards (triggered by long-press with no drag)
        .confirmationDialog(
            contextMenuAlbum?.displayDate ?? "",
            isPresented: Binding(get: { contextMenuAlbum != nil },
                                 set: { if !$0 { contextMenuAlbum = nil } }),
            titleVisibility: .visible
        ) {
            if let album = contextMenuAlbum {
                Button("Share Album") { shareAlbum(album) }
                Button("Edit Title & Cover") { editingAlbum = album }
                Button("Delete Album", role: .destructive) {
                    albumPendingDelete = album
                    showDeleteAlbumConfirm = true
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(albumPendingDelete?.displayDate ?? "")\"?",
            isPresented: $showDeleteAlbumConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Album and Photos", role: .destructive) {
                if let album = albumPendingDelete { library.deleteAlbum(album) }
            }
        }
        .sheet(item: $editingAlbum) { album in
            AlbumEditView(album: album, library: library)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: sharingImages)
        }
    }

    // MARK: - Album grid

    private var albumContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("iyso memory card")
                    .font(.system(size: 24, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .tracking(-1.2)
                    .padding(.leading, 13)
                    .padding(.top, 65)
                    .padding(.bottom, 22)

                if library.albums.isEmpty {
                    emptyState
                } else {
                    albumGrid
                }
            }
            .padding(.bottom, 120)
        }
        .overlay(floatingDragCard)
        .onPreferenceChange(AlbumFrameKey.self) { albumCellFrames = $0 }
        .onAppear { resetDragState() }
    }

    private var albumGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(118), spacing: 7), count: 3)
        return LazyVGrid(columns: columns, spacing: 17) {
            ForEach(library.albums) { album in
                let isDragging = draggingAlbumID == album.id
                let isDropTarget = dropTargetID == album.id

                // Plain view — no NavigationLink, no Button wrapper, no pressed state.
                // Tap and long-press are fully independent recognizers with no shared state.
                AlbumCircleCell(album: album, library: library, diameter: 118)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .opacity(isDragging ? 0.3 : 1.0)
                    .overlay(
                        isDropTarget
                            ? Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                .frame(width: 118, height: 118)
                            : nil
                    )
                    .animation(.easeInOut(duration: 0.15), value: isDragging)
                    .animation(.easeInOut(duration: 0.15), value: isDropTarget)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: AlbumFrameKey.self,
                                value: [album.id: geo.frame(in: .global)]
                            )
                        }
                    )
                    .gesture(albumInteractionGesture(for: album))
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 12)
    }

    // MARK: - Floating card during drag

    @ViewBuilder
    private var floatingDragCard: some View {
        if let albumID = draggingAlbumID,
           let album = library.albums.first(where: { $0.id == albumID }),
           dragLocation != .zero {
            AlbumCircleCell(album: album, library: library, diameter: 118)
                .scaleEffect(1.07)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .position(dragLocation)
                .allowsHitTesting(false)
                .animation(nil, value: dragLocation)
        }
    }

    // MARK: - Interaction gesture (long-press → context menu or drag-to-combine)

    // Placed INSIDE the NavigationLink label so the child gesture has priority:
    //   short tap  → long press fails  → NavigationLink activates (no delay)
    //   0.65s hold → long press fires  → NavigationLink blocked
    //     ↳ no significant drag → context menu (confirmationDialog)
    //     ↳ drag > 15pt over target   → combine albums
    private func albumInteractionGesture(for album: DateAlbum) -> some Gesture {
        LongPressGesture(minimumDuration: 0.65)
            .sequenced(before: DragGesture(minimumDistance: 10, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    guard draggingAlbumID == nil else { return }
                    draggingAlbumID = album.id
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case .second(true, let drag?):
                    guard draggingAlbumID == album.id else { return }
                    let dist = hypot(drag.translation.width, drag.translation.height)
                    if dist > 5 {
                        dragLocation = drag.location
                        updateDropTarget(at: drag.location, excluding: album.id)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                defer { resetDragState() }
                switch value {
                case .first(false):
                    // Long press failed — short tap. Navigate immediately.
                    navigationPath.append(album.id)
                case .second(true, let drag?):
                    guard draggingAlbumID == album.id else { return }
                    let dist = hypot(drag.translation.width, drag.translation.height)
                    if dist > 15 {
                        commitDrop(sourceID: album.id, at: drag.location)
                    } else {
                        contextMenuAlbum = album
                    }
                default:
                    if draggingAlbumID == album.id { contextMenuAlbum = album }
                }
            }
    }

    private func resetDragState() {
        withAnimation(.easeInOut(duration: 0.15)) {
            draggingAlbumID = nil
            dragLocation = .zero
            dropTargetID = nil
        }
    }

    private func updateDropTarget(at location: CGPoint, excluding albumID: String) {
        dropTargetID = albumCellFrames.first(where: { id, frame in
            id != albumID && frame.contains(location)
        })?.key
    }

    private func commitDrop(sourceID: String, at location: CGPoint) {
        updateDropTarget(at: location, excluding: sourceID)
        guard let targetID = dropTargetID else { return }
        library.combineAlbums(sourceID: sourceID, targetID: targetID)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Album share

    private func shareAlbum(_ album: DateAlbum) {
        var images: [UIImage] = []
        let group = DispatchGroup()
        album.assets.forEach { asset in
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

    // MARK: - Empty / denied states

    private var emptyState: some View {
        Text("No photos yet.\nTap the camera to capture your first.")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(Color(white: 0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.top, 80)
            .frame(maxWidth: .infinity)
    }

    private var permissionDenied: some View {
        VStack(spacing: 12) {
            Text("Photo access required")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            Text("Enable in Settings → Privacy → Photos.")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Album circle cell

struct AlbumCircleCell: View {
    let album: DateAlbum
    let library: PhotoLibraryManager
    let diameter: CGFloat

    @State private var thumbnail: UIImage?

    private var isTodayAlbum: Bool { album.id == "05.19.2026" }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 0x2a/255, green: 0x1a/255, blue: 0x14/255))
                    .frame(width: diameter, height: diameter)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter - 12, height: diameter - 12)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: diameter - 12, height: diameter - 12)
                        .frame(width: diameter, height: diameter)
                }

                if isTodayAlbum && !album.assets.isEmpty {
                    Text("new!")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.white)
                        .tracking(-0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color(red: 47/255, green: 31/255, blue: 24/255).opacity(0.8))
                        )
                        .offset(x: -4, y: -4)
                }
            }

            Text(album.displayDate)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0xd4/255))
                .tracking(-0.6)
                .frame(width: diameter)
                .multilineTextAlignment(.center)
        }
        .onAppear { loadThumbnail() }
        .onChange(of: album.assets.count) { _ in loadThumbnail() }
        .onChange(of: album.coverAssetID) { _ in loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let asset = album.coverAsset else { thumbnail = nil; return }
        let pt = diameter - 12
        let scale = UIScreen.main.scale
        library.thumbnail(for: asset, size: CGSize(width: pt * scale, height: pt * scale)) {
            thumbnail = $0
        }
    }
}

// MARK: - Circular photo cell (used by AlbumDetailView)

struct CircularPhotoCell: View {
    let asset: PHAsset
    let library: PhotoLibraryManager
    let diameter: CGFloat
    var isNewest: Bool = false

    @State private var thumbnail: UIImage?
    private var label: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM.dd.yyyy"
        return asset.creationDate.map { fmt.string(from: $0) } ?? ""
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 0x2a/255, green: 0x1a/255, blue: 0x14/255))
                    .frame(width: diameter, height: diameter)

                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter - 12, height: diameter - 12)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: diameter, height: diameter)
                } else {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: diameter - 12, height: diameter - 12)
                        .frame(width: diameter, height: diameter)
                }

                if isNewest {
                    Text("new!")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundColor(.white)
                        .tracking(-0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 50)
                                .fill(Color(red: 47/255, green: 31/255, blue: 24/255).opacity(0.8))
                        )
                        .offset(x: -4, y: -4)
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0xd4/255))
                .tracking(-0.6)
                .frame(width: diameter)
                .multilineTextAlignment(.center)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        let pt = diameter - 12
        let scale = UIScreen.main.scale
        library.thumbnail(for: asset, size: CGSize(width: pt * scale, height: pt * scale)) {
            thumbnail = $0
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
