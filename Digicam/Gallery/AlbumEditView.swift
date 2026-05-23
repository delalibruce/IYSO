import SwiftUI
import Photos
import UIKit

// Sheet for editing an album's title and cover photo.
struct AlbumEditView: View {
  /// Final surviving merged album id (already resolved).
    let albumID: String
    @ObservedObject var library: PhotoLibraryManager

    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    @State private var selectedCoverID: String?

    init(resolvedAlbumID: String, library: PhotoLibraryManager) {
        self.albumID = resolvedAlbumID
        self.library = library
        let album = library.album(for: resolvedAlbumID)
        _titleText = State(initialValue: album?.displayTitle ?? "")
        _selectedCoverID = State(initialValue: album?.coverAssetID)
    }

    /// Always read the latest merged asset list from the library (not a stale sheet snapshot).
    private var album: DateAlbum? {
        library.album(for: albumID)
    }

    var body: some View {
        Group {
            if let album {
                editContent(for: album)
            }
        }
    }

    private func editContent(for album: DateAlbum) -> some View {
        NavigationStack {
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    titleSection
                    coverSection(for: album)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(using: album) }
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Title section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(white: 0.6))

            TextField("", text: $titleText)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white)
                .accentColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.12))
                )
        }
    }

    // MARK: - Cover section

    private func coverSection(for album: DateAlbum) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cover Photo")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(white: 0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(album.assets, id: \.localIdentifier) { asset in
                        CoverPhotoOption(
                            asset: asset,
                            library: library,
                            isSelected: selectedCoverID == asset.localIdentifier
                                || (selectedCoverID == nil
                                    && asset.localIdentifier == album.assets.first?.localIdentifier)
                        )
                        .onTapGesture {
                            selectedCoverID = asset.localIdentifier
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                print("[AlbumEdit] cover picker showing assetCount=\(album.assets.count) for albumID=\(albumID)")
            }
        }
    }

    // MARK: - Save

    private func save(using album: DateAlbum) {
        let trimmed = titleText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != album.displayTitle {
            library.updateAlbumTitle(albumID: albumID, title: trimmed)
        }
        if let coverID = selectedCoverID, coverID != album.coverAssetID {
            library.setAlbumCover(albumID: albumID, assetLocalID: coverID)
        }
        dismiss()
    }
}

// MARK: - Cover photo option cell

private struct CoverPhotoOption: View {
    let asset: PHAsset
    let library: PhotoLibraryManager
    let isSelected: Bool

    @State private var thumbnail: UIImage?
    private let size: CGFloat = 80

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: size, height: size)

            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 8, height: size - 8)
                    .clipShape(Circle())
            }

            if isSelected {
                Circle()
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: size, height: size)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 22, height: 22))
                    .offset(x: size / 2 - 12, y: -(size / 2 - 12))
            }
        }
        .frame(width: size, height: size)
        .onAppear { loadThumb() }
    }

    private func loadThumb() {
        let scale = UIScreen.main.scale
        library.thumbnail(for: asset, size: CGSize(width: size * scale, height: size * scale)) {
            thumbnail = $0
        }
    }
}

// MARK: - Title-only edit sheet (gallery label tap)

struct AlbumTitleEditView: View {
    let album: DateAlbum
    let library: PhotoLibraryManager

    @Environment(\.dismiss) private var dismiss
    @State private var titleText: String
    @FocusState private var isTitleFocused: Bool

    init(album: DateAlbum, library: PhotoLibraryManager) {
        self.album = album
        self.library = library
        _titleText = State(initialValue: album.displayTitle)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                TextField("", text: $titleText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { save() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.12))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Edit Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundColor(.white)
                        .disabled(titleText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isTitleFocused = true
                }
            }
        }
        .presentationDetents([.height(168)])
    }

    private func save() {
        let trimmed = titleText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if trimmed != album.displayTitle {
            library.updateAlbumTitle(albumID: album.id, title: trimmed)
        }
        dismiss()
    }
}