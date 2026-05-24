import SwiftUI

struct AlbumSearchView: View {
    @ObservedObject var library: PhotoLibraryManager
    @Binding var navigationPath: [GalleryNav]

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var searchChromeHeight: CGFloat = 0

    private var results: [DateAlbum] {
        AlbumSearchUtility.filterAlbums(library.albums, query: searchText)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        SDCardScreenContainer { topPadding, _ in
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()
                searchScreenContent(topPadding: topPadding)
            }
            .memoryFlowSwipeToGoBack { dismiss() }
            .navigationBarHidden(true)
            .background(DisableSystemPopGesture())
        }
        .onAppear {
            appState.isGallerySearchPresented = true
            isSearchFocused = true
        }
        .onDisappear {
            appState.isGallerySearchPresented = false
        }
    }

    // MARK: - Layout

    private func searchScreenContent(topPadding: CGFloat) -> some View {
        let chromeScrollInset = max(searchChromeHeight, topPadding + 120)

        return ZStack(alignment: .top) {
            Group {
                if trimmedSearchText.isEmpty {
                    centeredHint("Search by date or album name")
                } else if results.isEmpty {
                    centeredHint("No album found")
                } else {
                    resultsList
                }
            }
            .padding(.top, chromeScrollInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                searchHeader(topPadding: topPadding)
                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            }
            .background {
                MemoryFlowHeaderScrim()
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: MemoryFlowHeaderLayoutHeightKey.self,
                        value: geo.size.height
                    )
                }
            )
        }
        .onPreferenceChange(MemoryFlowHeaderLayoutHeightKey.self) {
            searchChromeHeight = $0
        }
    }

    // MARK: - Header

    private func searchHeader(topPadding: CGFloat) -> some View {
        MemoryFlowHeader(
            title: "Search",
            subtitle: "",
            topPadding: topPadding,
            appliesScrim: false,
            trailing: {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
            }
        )
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(white: 0.55))

            TextField("Search your memory card…", text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .accentColor(.white)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
        )
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(results) { album in
                    Button {
                        library.markSeen(albumID: album.id)
                        navigationPath.append(.album(id: album.id))
                    } label: {
                        AlbumSearchResultRow(album: album, library: library)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func centeredHint(_ text: String) -> some View {
        GeometryReader { proxy in
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .frame(width: proxy.size.width)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height * 0.20
                )
        }
    }
}

// MARK: - Result row

private struct AlbumSearchResultRow: View {
    let album: DateAlbum
    let library: PhotoLibraryManager

    var body: some View {
        HStack(spacing: 14) {
            AlbumCircleThumbnail(
                album: album,
                library: library,
                diameter: 72,
                showNewBadge: false
            )

            VStack(alignment: .leading, spacing: 4) {
                if let customTitle = album.customTitle, !customTitle.isEmpty {
                    Text(customTitle)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(white: 0xd4/255))
                        .tracking(-0.6)
                        .lineLimit(2)

                    Text(album.canonicalDateLabel)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(white: 0.55))
                } else {
                    Text(album.canonicalDateLabel)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(white: 0xd4/255))
                        .tracking(-0.6)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
