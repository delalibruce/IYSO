import Photos
import UIKit

extension Notification.Name {
    static let digicamPhotoSaved = Notification.Name("digicam.photoSaved")
}

struct DateAlbum: Identifiable {
    let id: String           // "yyyy-MM-dd" — stable calendar key
    let date: Date
    var displayTitle: String // "Thursday May 21" or user override
    var assets: [PHAsset]   // sorted ascending by creationDate (oldest first = cover)
    var coverAssetID: String?
    var isSeen: Bool

    var coverAsset: PHAsset? {
        if let id = coverAssetID { return assets.first(where: { $0.localIdentifier == id }) }
        return assets.first
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

    func requestAccessAndLoad() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            authorizationStatus = current
            loadAlbums()
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized || status == .limited { self?.loadAlbums() }
            }
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
                assets: sorted,
                coverAssetID: nil,
                isSeen: false
            )
        }

        // Apply merges
        let merges = UserDefaults.standard.array(forKey: Self.albumMergesKey) as? [[String]] ?? []
        var indicesToRemove: [Int] = []
        for merge in merges {
            guard merge.count == 2 else { continue }
            let sourceID = merge[0], targetID = merge[1]
            guard let sourceIdx = built.firstIndex(where: { $0.id == sourceID }),
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
            if let t = titles[built[i].id] { built[i].displayTitle = t }
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

    // Removes photo from app index only — does not touch the Photos library.
    func deleteAsset(_ asset: PHAsset, completion: @escaping (Bool) -> Void = { _ in }) {
        var saved = UserDefaults.standard.stringArray(forKey: Self.capturedIDsKey) ?? []
        saved.removeAll { $0 == asset.localIdentifier }
        UserDefaults.standard.set(saved, forKey: Self.capturedIDsKey)
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
    }

    // MARK: - Image loading

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

    // MARK: - Date helpers

    static func dateKey(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func defaultDisplayTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE MMMM d"
        return fmt.string(from: date)
    }

    private static func computeRangeTitle(for assets: [PHAsset]) -> String {
        let dates = assets.compactMap { $0.creationDate }
        guard let earliest = dates.min(), let latest = dates.max() else { return "Album" }
        let cal = Calendar.current
        if cal.isDate(earliest, inSameDayAs: latest) {
            return defaultDisplayTitle(for: earliest)
        }
        let monthDay = DateFormatter()
        monthDay.dateFormat = "MMM d"
        let dayOnly = DateFormatter()
        dayOnly.dateFormat = "d"
        if cal.component(.month, from: earliest) == cal.component(.month, from: latest) {
            return "\(monthDay.string(from: earliest))–\(dayOnly.string(from: latest))"
        } else {
            return "\(monthDay.string(from: earliest))–\(monthDay.string(from: latest))"
        }
    }
}
