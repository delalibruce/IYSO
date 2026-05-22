import Photos
import UIKit

extension Notification.Name {
    static let digicamPhotoSaved = Notification.Name("digicam.photoSaved")
}

struct DateAlbum: Identifiable {
    let id: String
    var displayDate: String
    var assets: [PHAsset]
    var coverAssetID: String?
    var coverAsset: PHAsset? {
        if let id = coverAssetID { return assets.first(where: { $0.localIdentifier == id }) }
        return assets.first
    }
}

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var assets: [PHAsset] = []
    @Published var albums: [DateAlbum] = []

    static let capturedIDsKey   = "digicam.capturedPhotoIDs"
    static let albumMergesKey   = "digicam.albumMerges"   // [[String]]
    static let albumTitlesKey   = "digicam.albumTitles"   // [String: String]
    static let albumCoversKey   = "digicam.albumCovers"   // [String: String]

    private var photoSavedObserver: NSObjectProtocol?

    init() {
        photoSavedObserver = NotificationCenter.default.addObserver(
            forName: .digicamPhotoSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadAssets()
                self?.loadAlbums()
            }
        }
    }

    func requestAccessAndLoad() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            authorizationStatus = current
            loadAssets()
            loadAlbums()
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.loadAssets()
                    self?.loadAlbums()
                }
            }
        }
    }

    func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in loaded.append(asset) }
        assets = loaded
    }

    func loadAlbums() {
        let appIDs = Set(UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? [])

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        var allPhotos: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in allPhotos.append(asset) }

        var todayAssets: [PHAsset] = []
        if !appIDs.isEmpty {
            let captured = PHAsset.fetchAssets(withLocalIdentifiers: Array(appIDs), options: nil)
            captured.enumerateObjects { asset, _, _ in todayAssets.append(asset) }
            todayAssets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }

        let others = allPhotos.filter { !appIDs.contains($0.localIdentifier) }
        let pastDates = ["05.18.2026", "05.17.2026", "05.16.2026", "05.15.2026"]
        let chunkSize = 4

        var built: [DateAlbum] = [
            DateAlbum(id: "05.19.2026", displayDate: "05.19.2026", assets: todayAssets)
        ]
        for (i, date) in pastDates.enumerated() {
            let start = i * chunkSize
            guard start < others.count else { break }
            let end = min(start + chunkSize, others.count)
            built.append(DateAlbum(id: date, displayDate: date, assets: Array(others[start..<end])))
        }

        // Apply saved merges: source is absorbed into target, then removed
        let merges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        var indicesToRemove: [Int] = []
        for merge in merges {
            guard merge.count == 2 else { continue }
            let sourceID = merge[0], targetID = merge[1]
            guard let sourceIdx = built.firstIndex(where: { $0.id == sourceID }),
                  let targetIdx = built.firstIndex(where: { $0.id == targetID }),
                  !indicesToRemove.contains(sourceIdx) else { continue }
            let merged = (built[targetIdx].assets + built[sourceIdx].assets)
                .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            built[targetIdx].assets = merged
            built[targetIdx].displayDate = computeDisplayDate(for: merged)
            indicesToRemove.append(sourceIdx)
        }
        for idx in indicesToRemove.sorted(by: >) { built.remove(at: idx) }

        // Apply title overrides
        let titles = UserDefaults.standard.dictionary(forKey: Self.albumTitlesKey) as? [String: String] ?? [:]
        for i in built.indices {
            if let t = titles[built[i].id] { built[i].displayDate = t }
        }

        // Apply cover overrides
        let covers = UserDefaults.standard.dictionary(forKey: Self.albumCoversKey) as? [String: String] ?? [:]
        for i in built.indices {
            built[i].coverAssetID = covers[built[i].id]
        }

        albums = built
    }

    // MARK: - Album management

    func combineAlbums(sourceID: String, targetID: String) {
        var merges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        merges.append([sourceID, targetID])
        UserDefaults.standard.set(merges, forKey: Self.albumMergesKey)
        loadAlbums()
    }

    func setAlbumCover(albumID: String, assetLocalID: String) {
        var covers = UserDefaults.standard.dictionary(forKey: Self.albumCoversKey) as? [String: String] ?? [:]
        covers[albumID] = assetLocalID
        UserDefaults.standard.set(covers, forKey: Self.albumCoversKey)
        loadAlbums()
    }

    func updateAlbumTitle(albumID: String, title: String) {
        var titles = UserDefaults.standard.dictionary(forKey: Self.albumTitlesKey) as? [String: String] ?? [:]
        titles[albumID] = title
        UserDefaults.standard.set(titles, forKey: Self.albumTitlesKey)
        loadAlbums()
    }

    func deleteAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, _ in
            if success {
                var saved = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
                saved.removeAll { $0 == asset.localIdentifier }
                UserDefaults.standard.set(saved, forKey: Self.capturedIDsKey)
            }
            DispatchQueue.main.async {
                if success { self.loadAlbums() }
                completion(success)
            }
        }
    }

    func deleteAlbum(_ album: DateAlbum) {
        guard !album.assets.isEmpty else {
            removeAlbumMetadata(for: album.id)
            loadAlbums()
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(album.assets as NSArray)
        }) { success, _ in
            if success {
                let idsToRemove = Set(album.assets.map { $0.localIdentifier })
                var saved = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
                saved.removeAll { idsToRemove.contains($0) }
                UserDefaults.standard.set(saved, forKey: Self.capturedIDsKey)
                self.removeAlbumMetadata(for: album.id)
            }
            DispatchQueue.main.async { if success { self.loadAlbums() } }
        }
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
    }

    // MARK: - Image loading

    func thumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    func fullResImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    // MARK: - Helpers

    private func computeDisplayDate(for assets: [PHAsset]) -> String {
        let dates = assets.compactMap { $0.creationDate }
        guard let earliest = dates.min(), let latest = dates.max() else { return "unknown" }

        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM.dd.yyyy"
            return fmt.string(from: earliest)
        }

        let monthDay = DateFormatter()
        monthDay.dateFormat = "M.dd"
        let year = DateFormatter()
        year.dateFormat = "yy"
        return "\(monthDay.string(from: earliest))–\(monthDay.string(from: latest)).\(year.string(from: latest))"
    }
}
