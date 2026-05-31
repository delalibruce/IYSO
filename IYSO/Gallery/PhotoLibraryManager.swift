import Photos
import UIKit

extension Notification.Name {
    static let digicamPhotoSaved = Notification.Name("digicam.photoSaved")
}

struct DateAlbum: Identifiable {
    let id: String           // "yyyy-MM-dd" — stable calendar key
    let date: Date
    var displayTitle: String // "05.21.26", merged range, or user override
    var customTitle: String? // optional user-defined name; original date stays in `date` / `id`
    var assets: [PHAsset]   // sorted ascending by creationDate (oldest first = cover)
    var coverAssetID: String?
    var isSeen: Bool

    /// Canonical calendar key (`yyyy-MM-dd`); preserved even when `customTitle` is set.
    var dateKey: String { id }

    /// Default MM.DD.YY label (or merged range) for the album's capture date(s).
    var canonicalDateLabel: String {
        Self.formatCanonicalDateLabel(date: date, assets: assets)
    }

    private static func formatCanonicalDateLabel(date: Date, assets: [PHAsset]) -> String {
        let dates = assets.compactMap(\.creationDate)
        guard !dates.isEmpty else { return PhotoLibraryManager.albumDateLabel(for: date) }

        let cal = Calendar.current
        guard let earliest = dates.min(), let latest = dates.max() else {
            return PhotoLibraryManager.albumDateLabel(for: date)
        }
        if cal.isDate(earliest, inSameDayAs: latest) {
            return PhotoLibraryManager.albumDateLabel(for: earliest)
        }
        return "\(PhotoLibraryManager.albumDateLabel(for: earliest))–\(PhotoLibraryManager.albumDateLabel(for: latest))"
    }

    var coverAsset: PHAsset? {
        if let id = coverAssetID,
           let asset = assets.first(where: { $0.localIdentifier == id }) {
            return asset
        }
        return assets.first
    }

    /// Stable SwiftUI identity when the chosen cover changes.
    var galleryCoverViewID: String {
        let coverID = coverAssetID ?? coverAsset?.localIdentifier ?? "default"
        return "\(id)-\(coverID)"
    }
}

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var albums: [DateAlbum] = []

    static let capturedIDsKey        = "digicam.capturedPhotoIDs"
    static let albumMergesKey        = "digicam.albumMerges"
    static let albumTitlesKey        = "digicam.albumTitles"
    static let albumCoversKey        = "digicam.albumCovers"
    static let seenAlbumsKey         = "digicam.seenAlbums"
    static let photoFileNamesKey     = "digicam.photoFileNames"
    static let albumSystemVersionKey = "digicam.albumSystemVersion"

    private var photoSavedObserver: NSObjectProtocol?

    init() {
        migrateIfNeeded()
        photoSavedObserver = NotificationCenter.default.addObserver(
            forName: .digicamPhotoSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.loadAlbums() }
        }
    }

    // MARK: - One-time migration

    private func migrateIfNeeded() {
        let version = UserDefaults.standard.integer(forKey: Self.albumSystemVersionKey)
        guard version < 2 else { return }
        for key in [Self.capturedIDsKey, Self.albumMergesKey,
                    Self.albumTitlesKey, Self.albumCoversKey, Self.seenAlbumsKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(2, forKey: Self.albumSystemVersionKey)
    }

    // MARK: - Access

    /// Sync in-memory authorization state without triggering the system prompt.
    /// Photo library prompts belong only on `CapturePermissionSetupScreen`.
    func refreshAuthorizationStatusAndLoadIfAuthorized() {
        #if DEBUG
        if DebugOverrides.forceDeniedPhotos || DebugOverrides.suppressPermissionPrompts {
            authorizationStatus = .denied
            albums = []
            return
        }
        #endif
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = current
        if current == .authorized || current == .limited {
            loadAlbums()
        } else {
            albums = []
        }
    }

    // MARK: - Load

    func loadAlbums() {
        let capturedIDs = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
        guard !capturedIDs.isEmpty else { albums = []; return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: capturedIDs, options: nil)
        var allAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in allAssets.append(asset) }

        // Group by calendar day
        let cal = Calendar.current
        var dayMap: [String: (Date, [PHAsset])] = [:]
        for asset in allAssets {
            guard let date = asset.creationDate else { continue }
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let dayStart = cal.date(from: comps) else { continue }
            let key = Self.dateKey(from: dayStart)
            if dayMap[key] == nil { dayMap[key] = (dayStart, []) }
            dayMap[key]!.1.append(asset)
        }

        // Build initial albums, assets sorted oldest-first
        var built: [DateAlbum] = dayMap.map { key, pair in
            let (dayStart, assets) = pair
            let sorted = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            return DateAlbum(
                id: key,
                date: dayStart,
                displayTitle: Self.defaultDisplayTitle(for: dayStart),
                customTitle: nil,
                assets: sorted,
                coverAssetID: nil,
                isSeen: false
            )
        }

        // Apply merges (resolve chains so a merge into an already-merged album
        // still lands on the surviving combined album).
        let rawMerges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        let validMerges = rawMerges.filter { $0.count == 2 }
        let merges = validMerges.map { pair in
            [pair[0], Self.resolveMergeTarget(pair[1], merges: validMerges)]
        }
        var indicesToRemove: [Int] = []
        for merge in merges {
            let sourceID = merge[0], targetID = merge[1]
            guard sourceID != targetID,
                  let sourceIdx = built.firstIndex(where: { $0.id == sourceID }),
                  let targetIdx = built.firstIndex(where: { $0.id == targetID }),
                  !indicesToRemove.contains(sourceIdx) else { continue }
            let merged = (built[targetIdx].assets + built[sourceIdx].assets)
                .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            built[targetIdx].assets = merged
            built[targetIdx].displayTitle = Self.computeRangeTitle(for: merged)
            indicesToRemove.append(sourceIdx)
        }
        for idx in indicesToRemove.sorted(by: >) { built.remove(at: idx) }

        // Apply title overrides
        let titles = UserDefaults.standard.dictionary(forKey: Self.albumTitlesKey) as? [String: String] ?? [:]
        for i in built.indices {
            if let t = titles[built[i].id] {
                built[i].customTitle = t
                built[i].displayTitle = t
            }
        }

        // Apply cover overrides
        let covers = UserDefaults.standard.dictionary(forKey: Self.albumCoversKey) as? [String: String] ?? [:]
        for i in built.indices { built[i].coverAssetID = covers[built[i].id] }

        // Apply seen state
        let seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenAlbumsKey) ?? [])
        for i in built.indices { built[i].isSeen = seen.contains(built[i].id) }

        built.sort { $0.date > $1.date }
        albums = built
    }

    // MARK: - Merge resolution

    private var storedValidMerges: [[String]] {
        (UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? [])
            .filter { $0.count == 2 }
    }

    /// Follows stored merge records to the album that ultimately absorbed `albumID`.
    func resolvedAlbumID(for albumID: String) -> String {
        Self.resolveMergeTarget(albumID, merges: storedValidMerges)
    }

    /// Live album for editing/display, using merge resolution and full merged asset list.
    func album(for albumID: String) -> DateAlbum? {
        let resolvedID = resolvedAlbumID(for: albumID)
        guard let survivor = albums.first(where: { $0.id == resolvedID }) else { return nil }

        let mergedAssets = assetsMerged(into: resolvedID)
        let survivorIDs = Set(survivor.assets.map(\.localIdentifier))
        let mergedIDs = Set(mergedAssets.map(\.localIdentifier))
        guard mergedIDs != survivorIDs else { return survivor }

        var copy = survivor
        copy.assets = mergedAssets
        return copy
    }

    /// All assets belonging to the surviving merged album (union of survivor + any source albums still present).
    private func assetsMerged(into survivorID: String) -> [PHAsset] {
        let merges = storedValidMerges
        let sourceIDs = merges
            .filter { Self.resolveMergeTarget($0[1], merges: merges) == survivorID }
            .map(\.[0])

        var byLocalID: [String: PHAsset] = [:]
        func absorb(_ assets: [PHAsset]) {
            for asset in assets { byLocalID[asset.localIdentifier] = asset }
        }

        if let survivor = albums.first(where: { $0.id == survivorID }) {
            absorb(survivor.assets)
        }
        for sourceID in sourceIDs where sourceID != survivorID {
            if let source = albums.first(where: { $0.id == sourceID }) {
                absorb(source.assets)
            }
        }

        return byLocalID.values.sorted {
            ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
        }
    }

    // MARK: - Album management

    func markSeen(albumID: String) {
        var seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenAlbumsKey) ?? [])
        guard !seen.contains(albumID) else { return }
        seen.insert(albumID)
        UserDefaults.standard.set(Array(seen), forKey: Self.seenAlbumsKey)
        loadAlbums()
    }

    func combineAlbums(sourceID: String, targetID: String) {
        var merges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        let validMerges = merges.filter { $0.count == 2 }
        let resolvedTarget = Self.resolveMergeTarget(targetID, merges: validMerges)
        guard sourceID != resolvedTarget else { return }
        merges.append([sourceID, resolvedTarget])
        UserDefaults.standard.set(merges, forKey: Self.albumMergesKey)
        loadAlbums()
    }

    func setAlbumCover(albumID: String, assetLocalID: String) {
        let resolvedID = resolvedAlbumID(for: albumID)
        var covers = UserDefaults.standard.dictionary(forKey: Self.albumCoversKey) as? [String: String] ?? [:]
        covers[resolvedID] = assetLocalID
        UserDefaults.standard.set(covers, forKey: Self.albumCoversKey)
        if let index = albums.firstIndex(where: { $0.id == resolvedID }) {
            albums[index].coverAssetID = assetLocalID
        }
        loadAlbums()
    }

    func updateAlbumTitle(albumID: String, title: String) {
        let resolvedID = resolvedAlbumID(for: albumID)
        var titles = UserDefaults.standard.dictionary(forKey: Self.albumTitlesKey) as? [String: String] ?? [:]
        titles[resolvedID] = title
        UserDefaults.standard.set(titles, forKey: Self.albumTitlesKey)
        loadAlbums()
    }

    func photoDisplayName(for asset: PHAsset) -> String {
        let overrides = UserDefaults.standard.dictionary(forKey: Self.photoFileNamesKey) as? [String: String] ?? [:]
        if let custom = overrides[asset.localIdentifier], !custom.isEmpty {
            return custom
        }
        return PHAssetResource.assetResources(for: asset).first?.originalFilename ?? ""
    }

    func updatePhotoFileName(assetLocalID: String, fileName: String) {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var names = UserDefaults.standard.dictionary(forKey: Self.photoFileNamesKey) as? [String: String] ?? [:]
        names[assetLocalID] = trimmed
        UserDefaults.standard.set(names, forKey: Self.photoFileNamesKey)
        objectWillChange.send()
    }

    // Removes photo from app index only — does not touch the Photos library.
    func deleteAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void = { _ in }) {
        var saved = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
        saved.removeAll { $0 == asset.localIdentifier }
        UserDefaults.standard.set(saved, forKey: Self.capturedIDsKey)

        var fileNames = UserDefaults.standard.dictionary(forKey: Self.photoFileNamesKey) as? [String: String] ?? [:]
        fileNames.removeValue(forKey: asset.localIdentifier)
        UserDefaults.standard.set(fileNames, forKey: Self.photoFileNamesKey)

        loadAlbums()
        completion(true)
    }

    // Removes all album photos from app index only — does not touch the Photos library.
    func deleteAlbum(_ album: DateAlbum) {
        let idsToRemove = Set(album.assets.map { $0.localIdentifier })
        var saved = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
        saved.removeAll { idsToRemove.contains($0) }
        UserDefaults.standard.set(saved, forKey: Self.capturedIDsKey)
        removeAlbumMetadata(for: album.id)
        loadAlbums()
    }

    private func removeAlbumMetadata(for albumID: String) {
        var merges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        merges.removeAll { $0.contains(albumID) }
        UserDefaults.standard.set(merges, forKey: Self.albumMergesKey)

        var titles = UserDefaults.standard.dictionary(forKey: Self.albumTitlesKey) as? [String: String] ?? [:]
        titles.removeValue(forKey: albumID)
        UserDefaults.standard.set(titles, forKey: Self.albumTitlesKey)

        var covers = UserDefaults.standard.dictionary(forKey: Self.albumCoversKey) as? [String: String] ?? [:]
        covers.removeValue(forKey: albumID)
        UserDefaults.standard.set(covers, forKey: Self.albumCoversKey)

        var seen = Set(UserDefaults.standard.stringArray(forKey: Self.seenAlbumsKey) ?? [])
        seen.remove(albumID)
        UserDefaults.standard.set(Array(seen), forKey: Self.seenAlbumsKey)

        // Remove file-name overrides for photos no longer referenced by the app index.
        var fileNames = UserDefaults.standard.dictionary(forKey: Self.photoFileNamesKey) as? [String: String] ?? [:]
        let activeIDs = Set(UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? [])
        fileNames = fileNames.filter { activeIDs.contains($0.key) }
        UserDefaults.standard.set(fileNames, forKey: Self.photoFileNamesKey)
    }

    // MARK: - Image loading

    private static let coverThumbnailOversample: CGFloat = 1.5

    private let imageManager = PHCachingImageManager()
    private static let coverThumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()

    nonisolated static func coverThumbnailCacheKey(for asset: PHAsset, size: CGSize) -> String {
        "\(asset.localIdentifier)|\(Int(size.width))x\(Int(size.height))"
    }

    func cachedCoverThumbnail(for asset: PHAsset, size: CGSize) -> UIImage? {
        let key = Self.coverThumbnailCacheKey(for: asset, size: size) as NSString
        return Self.coverThumbnailCache.object(forKey: key)
    }

    /// Pixel size for album cover thumbnails — larger than display size so fisheye processing can downscale.
    nonisolated static func coverThumbnailPixelSize(
        innerDiameter: CGFloat,
        oversample: CGFloat = coverThumbnailOversample
    ) -> CGSize {
        let scale = UIScreen.main.scale
        let side = innerDiameter * scale * oversample
        return CGSize(width: side, height: side)
    }

    private var coverThumbnailOptions: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        return options
    }

    /// High-quality single delivery for peephole album covers (avoids degraded-then-final flicker).
    func coverThumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let key = Self.coverThumbnailCacheKey(for: asset, size: size) as NSString
        if let cached = Self.coverThumbnailCache.object(forKey: key) {
            completion(cached)
            return
        }

        imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: coverThumbnailOptions
        ) { image, _ in
            if let image {
                let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                Self.coverThumbnailCache.setObject(image, forKey: key, cost: cost)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    func startCachingCoverThumbnails(for assets: [PHAsset], innerDiameter: CGFloat) {
        guard !assets.isEmpty else { return }
        let size = Self.coverThumbnailPixelSize(innerDiameter: innerDiameter)
        imageManager.startCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFill,
            options: coverThumbnailOptions
        )
    }

    func stopCachingCoverThumbnails(for assets: [PHAsset], innerDiameter: CGFloat) {
        guard !assets.isEmpty else { return }
        let size = Self.coverThumbnailPixelSize(innerDiameter: innerDiameter)
        imageManager.stopCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFill,
            options: coverThumbnailOptions
        )
    }

    func stopAllCoverThumbnailCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    func thumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: size, contentMode: .aspectFill, options: options
        ) { image, _ in DispatchQueue.main.async { completion(image) } }
    }

    func fullResImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options
        ) { image, _ in DispatchQueue.main.async { completion(image) } }
    }

    /// Exports a single on-disk file for share workflows that should include exactly one asset.
    func exportAssetFileURL(for asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo })
            ?? resources.first
        guard let resource else {
            completion(nil)
            return
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("digicam-share", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            completion(nil)
            return
        }

        let filename = resource.originalFilename.isEmpty ? UUID().uuidString : resource.originalFilename
        let outputURL = tempDirectory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: resource, toFile: outputURL, options: options) { error in
            DispatchQueue.main.async {
                completion(error == nil ? outputURL : nil)
            }
        }
    }

    // MARK: - Date helpers

    nonisolated static func dateKey(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    nonisolated static func albumDateLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "MM.dd.yy"
        return fmt.string(from: date)
    }

    nonisolated static func albumMonthLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }

    nonisolated static func itemCountLabel(count: Int) -> String {
        count == 1 ? "1 Item" : "\(count) Items"
    }

    private static func defaultDisplayTitle(for date: Date) -> String {
        albumDateLabel(for: date)
    }

    /// Follows stored merge records to the album that ultimately absorbed `albumID`.
    private static func resolveMergeTarget(_ albumID: String, merges: [[String]]) -> String {
        var current = albumID
        while let merge = merges.last(where: { $0[0] == current }), merge.count > 1 {
            current = merge[1]
        }
        return current
    }

    private static func computeRangeTitle(for assets: [PHAsset]) -> String {
        let dates = assets.compactMap { $0.creationDate }
        guard let earliest = dates.min(), let latest = dates.max() else { return "Album" }
        let cal = Calendar.current
        if cal.isDate(earliest, inSameDayAs: latest) {
            return defaultDisplayTitle(for: earliest)
        }
        let start = albumDateLabel(for: earliest)
        let end = albumDateLabel(for: latest)
        return "\(start)–\(end)"
    }
}
