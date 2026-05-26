import SwiftUI
import Photos
import UIKit

enum GalleryNav: Hashable {
    case search
    case album(id: String)
}

private enum GalleryScrollContent {
    static let coordinateSpaceName = "galleryScrollContent"
}

private struct AlbumFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Circle-top Y in scroll content space (stable while scrolling; used with content offset).
private struct AlbumCircleContentYKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Layout constants for the Memory Card album grid — must match `albumGrid` spacing/sizes.
private enum GalleryAlbumGridMetrics {
    static let columns = 2
    static let circleDiameter: CGFloat = 179
    static let gridTopPadding: CGFloat = 10
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 20
    static let thumbnailLabelSpacing: CGFloat = 10
    /// Approximate height of the two-line date label under each circle.
    static let dateLabelHeight: CGFloat = 40

    /// ~16pt on reference-width phones; scales slightly for narrower/wider devices.
    static var albumTitleFontSize: CGFloat {
        let referenceWidth: CGFloat = 393
        let scale = min(max(UIScreen.main.bounds.width / referenceWidth, 0.88), 1.02)
        return 16 * scale
    }

    /// Vertical distance between the top of one row's circle and the next.
    static var rowStride: CGFloat {
        circleDiameter + thumbnailLabelSpacing + dateLabelHeight + rowSpacing
    }

    /// Y offset of a circle's top edge inside scroll content (index 0 = newest album).
    static func circleTopContentY(albumIndex: Int) -> CGFloat {
        let row = albumIndex / columns
        return gridTopPadding + CGFloat(row) * rowStride
    }
}

/// Reports `UIScrollView` content offset on every scroll frame (GeometryReader does not).
private struct ScrollOffsetTracker: UIViewRepresentable {
    let onScroll: (_ contentOffsetY: CGFloat, _ scrollViewGlobalMinY: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = uiView.enclosingScrollView else { return }
            context.coordinator.observe(scrollView)
            context.coordinator.report(scrollView)
        }
    }

    final class Coordinator: NSObject {
        let onScroll: (CGFloat, CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        init(onScroll: @escaping (CGFloat, CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func observe(_ scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else { return }
            observation?.invalidate()
            self.scrollView = scrollView
            observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                self?.report(scrollView)
            }
        }

        func report(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let globalMinY = scrollView.convert(scrollView.bounds, to: nil).minY
            DispatchQueue.main.async { [onScroll] in
                onScroll(offsetY, globalMinY)
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        sequence(first: self as UIView, next: { $0.superview })
            .compactMap { $0 as? UIScrollView }
            .first
    }
}

// MARK: - Album circle gestures (UIKit)

/// Transparent hit target on each album circle. Uses tap + long-press only (no DragGesture on the
/// cell). Long press runs simultaneously with the grid `UIScrollView` pan so vertical drags scroll
/// until the press succeeds; drag/stack tracking uses the long-press recognizer's `.changed` phase.
private struct AlbumCircleGestureOverlay: UIViewRepresentable {
    var onTap: () -> Void
    var onLongPressBegan: (CGPoint) -> Void
    var onLongPressChanged: (CGPoint) -> Void
    var onLongPressEnded: (_ location: CGPoint, _ dragDistance: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> AlbumCircleHitView {
        let view = AlbumCircleHitView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = 10
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        tap.require(toFail: longPress)
        view.addGestureRecognizer(longPress)

        context.coordinator.hostView = view
        context.coordinator.tapRecognizer = tap
        context.coordinator.longPressRecognizer = longPress
        return view
    }

    func updateUIView(_ uiView: AlbumCircleHitView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        coordinator.onLongPressBegan = onLongPressBegan
        coordinator.onLongPressChanged = onLongPressChanged
        coordinator.onLongPressEnded = onLongPressEnded

        DispatchQueue.main.async {
            guard let scrollView = uiView.enclosingScrollView,
                  let tap = coordinator.tapRecognizer else { return }
            tap.require(toFail: scrollView.panGestureRecognizer)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void = {}
        var onLongPressBegan: (CGPoint) -> Void = { _ in }
        var onLongPressChanged: (CGPoint) -> Void = { _ in }
        var onLongPressEnded: (_ location: CGPoint, _ dragDistance: CGFloat) -> Void = { _, _ in }

        weak var hostView: UIView?
        weak var tapRecognizer: UITapGestureRecognizer?
        weak var longPressRecognizer: UILongPressGestureRecognizer?

        private weak var scrollView: UIScrollView?
        private var didEnterDragMode = false
        private var beganLocation: CGPoint = .zero

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === longPressRecognizer,
                  let scrollView = resolveScrollView(),
                  other === scrollView.panGestureRecognizer else {
                return false
            }
            return true
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onTap()
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: nil)
            switch recognizer.state {
            case .began:
                didEnterDragMode = true
                beganLocation = location
                scrollView?.isScrollEnabled = false
                onLongPressBegan(location)
            case .changed:
                guard didEnterDragMode else { return }
                onLongPressChanged(location)
            case .ended, .cancelled, .failed:
                defer { finishLongPressInteraction() }
                guard didEnterDragMode else { return }
                let distance = hypot(location.x - beganLocation.x, location.y - beganLocation.y)
                onLongPressEnded(location, distance)
            default:
                break
            }
        }

        private func finishLongPressInteraction() {
            didEnterDragMode = false
            beganLocation = .zero
            scrollView?.isScrollEnabled = true
        }

        private func resolveScrollView() -> UIScrollView? {
            if let scrollView { return scrollView }
            let found = hostView?.enclosingScrollView
            scrollView = found
            return found
        }
    }
}

/// Circular hit testing so only the visible disc receives touches (not the square cell).
private final class AlbumCircleHitView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return hypot(point.x - center.x, point.y - center.y) <= radius
    }
}

private struct AlbumEditorSheetItem: Identifiable {
    let id: String
}

struct GalleryRootView: View {
    @ObservedObject var library: PhotoLibraryManager
    @EnvironmentObject private var appBlocking: AppBlockingManager

    @State private var navigationPath: [GalleryNav] = []
    @State private var isSettingsPresented = false

    private static let albumDragThreshold: CGFloat = 25

    // Long-press: armed (pulse + menu) → drag (floating card after threshold)
    @State private var armingAlbumID: String? = nil
    @State private var pressBeganLocation: CGPoint = .zero
    @State private var albumPulseScale: CGFloat = 1.0

    // Drag-to-combine state
    @State private var draggingAlbumID: String? = nil
    @State private var dragPosition: CGPoint = .zero
    @State private var hoverTargetID: String? = nil
    @State private var cardFrames: [String: CGRect] = [:]

    // Context menu (long press)
    @State private var contextMenuAlbum: DateAlbum? = nil
    @State private var editingAlbumSheet: AlbumEditorSheetItem? = nil
    @State private var titleEditingAlbum: DateAlbum? = nil
    @State private var albumPendingDelete: DateAlbum? = nil
    @State private var showDeleteAlbumConfirm = false
    @State private var sharingImages: [UIImage] = []
    @State private var isShareSheetPresented = false

    @State private var currentMonthYear = ""
    @State private var headerBottomY: CGFloat = 0
    @State private var memoryFlowHeaderLayoutHeight: CGFloat = 0
    @State private var scrollContentOffsetY: CGFloat = 0
    @State private var scrollViewGlobalMinY: CGFloat = 0
    @State private var circleContentY: [String: CGFloat] = [:]
    @State private var measuredRowStride: CGFloat?

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SDCardScreenContainer { topPadding, _ in
                ZStack {
                    PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                    switch library.authorizationStatus {
                    case .authorized, .limited:
                        albumContent(topPadding: topPadding)
                    case .denied, .restricted:
                        permissionDenied
                    default:
                        Color.clear
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GalleryNav.self) { route in
                switch route {
                case .search:
                    AlbumSearchView(library: library, navigationPath: $navigationPath)
                case .album(let albumID):
                    if let album = library.albums.first(where: { $0.id == albumID }) {
                        AlbumDetailView(
                            assets: album.assets,
                            albumTitle: album.canonicalDateLabel,
                            albumID: albumID,
                            library: library
                        )
                    }
                }
            }
        }
        .onAppear { library.requestAccessAndLoad() }
        .onReceive(library.$albums) { _ in
            guard let menuAlbum = contextMenuAlbum else { return }
            let resolvedID = library.resolvedAlbumID(for: menuAlbum.id)
            contextMenuAlbum = library.album(for: resolvedID) ?? contextMenuAlbum
        }
        .confirmationDialog(
            contextMenuAlbum?.displayTitle ?? "",
            isPresented: Binding(
                get: { contextMenuAlbum != nil },
                set: { if !$0 { contextMenuAlbum = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let album = contextMenuAlbum {
                Button("Share Album") { shareAlbum(album) }
                Button("Edit Title & Cover") {
                    presentAlbumEditor(for: album)
                }
                Button("Delete Album", role: .destructive) {
                    albumPendingDelete = album
                    showDeleteAlbumConfirm = true
                }
            }
        }
        .memoryFlowDeleteConfirmation(
            "Delete \"\(albumPendingDelete?.displayTitle ?? "")\"?",
            isPresented: $showDeleteAlbumConfirm,
            deleteButtonTitle: "Delete Album and Photos"
        ) {
            if let album = albumPendingDelete { library.deleteAlbum(album) }
        }
        .sheet(item: $editingAlbumSheet) { item in
            AlbumEditView(resolvedAlbumID: item.id, library: library)
        }
        .sheet(item: $titleEditingAlbum) { album in
            AlbumTitleEditView(album: album, library: library)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(items: sharingImages)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(appBlocking)
        }
    }

    // MARK: - Album grid

    private func albumContent(topPadding: CGFloat) -> some View {
        let headerScrollInset = max(memoryFlowHeaderLayoutHeight, topPadding + 72)

        return ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollOffsetTracker { offsetY, scrollMinY in
                        scrollContentOffsetY = offsetY
                        scrollViewGlobalMinY = scrollMinY
                        updateVisibleMonthYear()
                    }
                    .frame(width: 0, height: 0)

                    Color.clear.frame(height: headerScrollInset)

                    if !library.albums.isEmpty {
                        albumGrid
                            .padding(.top, 10)
                    }
                }
                .padding(.bottom, 120)
                .coordinateSpace(name: GalleryScrollContent.coordinateSpaceName)
            }

            MemoryFlowHeader(
                title: "memory card",
                subtitle: currentMonthYear,
                topPadding: topPadding,
                leading: {
                    ModeBadge(mode: .memory)
                },
                trailing: {
                    HStack(spacing: 4) {
                        Button(action: { isSettingsPresented = true }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Settings")

                        Button(action: { navigationPath.append(.search) }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("Search")
                    }
                }
            )
        }
        .overlay(floatingDragCard)
        .onPreferenceChange(MemoryFlowHeaderLayoutHeightKey.self) {
            memoryFlowHeaderLayoutHeight = $0
        }
        .onPreferenceChange(MemoryFlowHeaderBottomKey.self) {
            headerBottomY = $0
            updateVisibleMonthYear()
        }
        .onPreferenceChange(AlbumCircleContentYKey.self) {
            circleContentY = $0
            calibrateRowStride(from: $0)
            updateVisibleMonthYear()
        }
        .onPreferenceChange(AlbumFrameKey.self) { cardFrames = $0 }
        .onChange(of: library.albums.map(\.id)) { _ in
            resetMonthYear()
            prefetchAlbumCoverThumbnails()
        }
        .onAppear {
            armingAlbumID = nil
            pressBeganLocation = .zero
            draggingAlbumID = nil
            dragPosition = .zero
            hoverTargetID = nil
            contextMenuAlbum = nil
            resetMonthYear()
            prefetchAlbumCoverThumbnails()
        }
        .onDisappear {
            library.stopAllCoverThumbnailCaching()
        }
    }

    private func prefetchAlbumCoverThumbnails() {
        let assets = library.albums.compactMap(\.coverAsset)
        let innerDiameter = GalleryAlbumGridMetrics.circleDiameter - 12
        library.startCachingCoverThumbnails(for: assets, innerDiameter: innerDiameter)
    }

    private func monthYearLabel(for date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }

    private func resetMonthYear() {
        guard let first = library.albums.first else {
            currentMonthYear = ""
            return
        }
        currentMonthYear = monthYearLabel(for: first.date)
        updateVisibleMonthYear()
    }

    /// Header bottom in global coords; falls back to scroll view top when preference is missing.
    private func effectiveHeaderBottomY() -> CGFloat {
        if headerBottomY > 0 { return headerBottomY }
        return scrollViewGlobalMinY
    }

    /// Scroll-content Y where the header bottom meets the grid (circle top crosses this line).
    private func activationContentY() -> CGFloat {
        guard scrollViewGlobalMinY > 0 else { return max(0, scrollContentOffsetY) }
        let headerBottom = effectiveHeaderBottomY()
        return max(0, scrollContentOffsetY + (headerBottom - scrollViewGlobalMinY))
    }

    private func effectiveRowStride() -> CGFloat {
        measuredRowStride ?? GalleryAlbumGridMetrics.rowStride
    }

    /// Derive row stride from laid-out circle positions (more accurate than estimates).
    private func calibrateRowStride(from positions: [String: CGFloat]) {
        let ys = Array(Set(positions.values)).sorted()
        guard ys.count >= 2 else { return }

        var rowTops: [CGFloat] = []
        for y in ys {
            if let last = rowTops.last, abs(y - last) < 12 { continue }
            rowTops.append(y)
        }
        guard rowTops.count >= 2 else { return }

        let stride = rowTops[1] - rowTops[0]
        guard stride > 100, stride < 400 else { return }
        measuredRowStride = stride
    }

    private func circleTopContentY(forAlbumIndex index: Int) -> CGFloat {
        let row = index / GalleryAlbumGridMetrics.columns
        return GalleryAlbumGridMetrics.gridTopPadding + CGFloat(row) * effectiveRowStride()
    }

    /// Top visible grid row from scroll position; snaps to left column album for stable month labels.
    private func activeAlbum(for activationY: CGFloat) -> DateAlbum {
        let stride = effectiveRowStride()
        let padding = GalleryAlbumGridMetrics.gridTopPadding
        let circleSize = GalleryAlbumGridMetrics.circleDiameter

        var topRow = 0
        var topCircleY = CGFloat.infinity
        for index in library.albums.indices {
            let top = circleTopContentY(forAlbumIndex: index)
            if top + circleSize > activationY, top < topCircleY {
                topCircleY = top
                topRow = index / GalleryAlbumGridMetrics.columns
            }
        }

        if topCircleY.isInfinite {
            topRow = max(0, Int(floor((activationY - padding) / stride)))
        }

        let albumIndex = min(topRow * GalleryAlbumGridMetrics.columns, library.albums.count - 1)
        return library.albums[albumIndex]
    }

    private func updateVisibleMonthYear() {
        guard !library.albums.isEmpty else {
            currentMonthYear = ""
            return
        }

        let label = monthYearLabel(for: activeAlbum(for: activationContentY()).date)
        if currentMonthYear != label {
            currentMonthYear = label
        }
    }

    private var albumGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: GalleryAlbumGridMetrics.columnSpacing),
            count: GalleryAlbumGridMetrics.columns
        )
        return LazyVGrid(columns: columns, spacing: GalleryAlbumGridMetrics.rowSpacing) {
            ForEach(library.albums) { album in
                let isDragging = draggingAlbumID == album.id
                let isHover = hoverTargetID == album.id

                VStack(spacing: GalleryAlbumGridMetrics.thumbnailLabelSpacing) {
                    AlbumCircleThumbnail(
                        album: album,
                        library: library,
                        diameter: GalleryAlbumGridMetrics.circleDiameter,
                        showHoverRing: isHover,
                        showPeepholeEffect: true
                    )
                    .id(album.galleryCoverViewID)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: AlbumCircleContentYKey.self,
                                    value: [
                                        album.id: geo.frame(
                                            in: .named(GalleryScrollContent.coordinateSpaceName)
                                        ).minY
                                    ]
                                )
                            }
                        )
                        .scaleEffect(
                            isDragging ? 0.95 : (armingAlbumID == album.id ? albumPulseScale : 1.0)
                        )
                        .opacity(isDragging ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isDragging)
                        .animation(.easeInOut(duration: 0.15), value: isHover)
                        .overlay {
                            AlbumCircleGestureOverlay(
                                onTap: {
                                    if contextMenuAlbum != nil {
                                        contextMenuAlbum = nil
                                        return
                                    }
                                    guard draggingAlbumID == nil, armingAlbumID == nil else { return }
                                    library.markSeen(albumID: album.id)
                                    navigationPath.append(.album(id: album.id))
                                },
                                onLongPressBegan: { location in
                                    guard draggingAlbumID == nil, armingAlbumID == nil else { return }
                                    armingAlbumID = album.id
                                    pressBeganLocation = location
                                    contextMenuAlbum = album
                                    triggerAlbumPulse()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                },
                                onLongPressChanged: { location in
                                    guard armingAlbumID == album.id || draggingAlbumID == album.id else {
                                        return
                                    }
                                    let distance = hypot(
                                        location.x - pressBeganLocation.x,
                                        location.y - pressBeganLocation.y
                                    )
                                    guard distance > Self.albumDragThreshold else { return }

                                    if draggingAlbumID == nil {
                                        contextMenuAlbum = nil
                                        draggingAlbumID = album.id
                                        dragPosition = location
                                    }
                                    dragPosition = location
                                    updateHoverTarget(at: location, excluding: album.id)
                                },
                                onLongPressEnded: { location, distance in
                                    defer {
                                        armingAlbumID = nil
                                        pressBeganLocation = .zero
                                        if draggingAlbumID == album.id {
                                            resetDragState()
                                        }
                                    }
                                    let wasActive = armingAlbumID == album.id || draggingAlbumID == album.id
                                    guard wasActive else { return }

                                    if distance > Self.albumDragThreshold {
                                        if draggingAlbumID == nil {
                                            contextMenuAlbum = nil
                                            draggingAlbumID = album.id
                                        }
                                        commitDrop(sourceID: album.id, at: location)
                                    } else if contextMenuAlbum == nil {
                                        contextMenuAlbum = album
                                    }
                                }
                            )
                            .frame(
                                width: GalleryAlbumGridMetrics.circleDiameter,
                                height: GalleryAlbumGridMetrics.circleDiameter
                            )
                        }

                    AlbumCircleDateLabel(
                        album: album,
                        diameter: GalleryAlbumGridMetrics.circleDiameter
                    ) {
                        guard draggingAlbumID == nil, armingAlbumID == nil else { return }
                        titleEditingAlbum = album
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: AlbumFrameKey.self,
                            value: [album.id: geo.frame(in: .global)]
                        )
                    }
                )
            }
        }
        .padding(.leading, 13)
        .padding(.trailing, 13)
    }

    // MARK: - Floating drag card

    @ViewBuilder
    private var floatingDragCard: some View {
        if let albumID = draggingAlbumID,
           let album = library.albums.first(where: { $0.id == albumID }),
           dragPosition != .zero {
            AlbumCircleCell(
                album: album,
                library: library,
                diameter: GalleryAlbumGridMetrics.circleDiameter
            )
                .scaleEffect(1.07)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .position(dragPosition)
                .allowsHitTesting(false)
                .animation(nil, value: dragPosition)
        }
    }

    private func resetDragState() {
        withAnimation(.easeInOut(duration: 0.15)) {
            draggingAlbumID = nil
            dragPosition = .zero
            hoverTargetID = nil
        }
    }

    private func triggerAlbumPulse() {
        albumPulseScale = 0.96
        withAnimation(.easeOut(duration: 0.1)) {
            albumPulseScale = 1.05
        }
        withAnimation(.easeInOut(duration: 0.14).delay(0.1)) {
            albumPulseScale = 1.0
        }
    }

    private func updateHoverTarget(at location: CGPoint, excluding albumID: String) {
        hoverTargetID = cardFrames.first(where: { id, frame in
            id != albumID && frame.contains(location)
        })?.key
    }

    private func commitDrop(sourceID: String, at location: CGPoint) {
        updateHoverTarget(at: location, excluding: sourceID)
        guard let targetID = hoverTargetID else { return }
        library.combineAlbums(sourceID: sourceID, targetID: targetID)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Album edit sheet

    private func presentAlbumEditor(for tappedAlbum: DateAlbum) {
        let tappedID = tappedAlbum.id
        let resolvedID = library.resolvedAlbumID(for: tappedID)
        let resolvedAlbum = library.album(for: tappedID)
        let staleCount = tappedAlbum.assets.count
        let resolvedCount = resolvedAlbum?.assets.count ?? 0

        print("[AlbumEdit] tapped album id=\(tappedID)")
        print("[AlbumEdit] resolved album id=\(resolvedID)")
        print("[AlbumEdit] stale/tapped asset count=\(staleCount)")
        print("[AlbumEdit] resolved live asset count=\(resolvedCount)")

        guard let resolvedAlbum else {
            print("[AlbumEdit] resolved album missing for id=\(resolvedID); not opening sheet")
            return
        }

        print("[AlbumEdit] opening sheet with \(resolvedAlbum.assets.count) assets")
        editingAlbumSheet = AlbumEditorSheetItem(id: resolvedID)
    }

    // MARK: - Share album

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

    // MARK: - Permission denied

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

struct AlbumCircleDateLabel: View {
    let album: DateAlbum
    let diameter: CGFloat
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    titleText
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit album title, \(album.displayTitle)")
                .accessibilityHint("Opens title editor")
            } else {
                titleText
            }
        }
    }

    private var titleText: some View {
        Text(album.displayTitle)
            .font(.system(size: GalleryAlbumGridMetrics.albumTitleFontSize, weight: .regular))
            .foregroundColor(Color(white: 0xd4/255))
            .tracking(-0.6)
            .frame(width: diameter)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
}

struct AlbumCircleThumbnail: View {
    let album: DateAlbum
    let library: PhotoLibraryManager
    let diameter: CGFloat
    var showNewBadge: Bool = true
    var showHoverRing: Bool = false
    /// Peephole glass ring/glow — off by default; enable for memory-card album covers only.
    var showPeepholeEffect: Bool = false

    @State private var thumbnail: UIImage?
    @State private var loadedCoverKey: String?

    init(
        album: DateAlbum,
        library: PhotoLibraryManager,
        diameter: CGFloat,
        showNewBadge: Bool = true,
        showHoverRing: Bool = false,
        showPeepholeEffect: Bool = false
    ) {
        self.album = album
        self.library = library
        self.diameter = diameter
        self.showNewBadge = showNewBadge
        self.showHoverRing = showHoverRing
        self.showPeepholeEffect = showPeepholeEffect

        let coverID = album.coverAssetID ?? album.coverAsset?.localIdentifier ?? ""
        let coverKey = "\(album.id)-\(coverID)"
        let innerDiameter = diameter - 12
        let size = PhotoLibraryManager.coverThumbnailPixelSize(innerDiameter: innerDiameter)
        let cached = album.coverAsset.flatMap { library.cachedCoverThumbnail(for: $0, size: size) }

        _thumbnail = State(initialValue: cached)
        _loadedCoverKey = State(initialValue: cached != nil ? coverKey : nil)
    }

    private var innerDiameter: CGFloat { diameter - 12 }

    private var isUnviewedAlbum: Bool {
        !album.isSeen && !album.assets.isEmpty
    }

    private var coverCacheKey: String {
        let coverID = album.coverAssetID ?? album.coverAsset?.localIdentifier ?? ""
        return "\(album.id)-\(coverID)"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showPeepholeEffect {
                if let thumbnail {
                    PeepholeAlbumCover(
                        imageSource: .uiImage(thumbnail, cacheKey: coverCacheKey),
                        size: diameter,
                        isNew: isUnviewedAlbum
                    )
                } else {
                    albumCoverLoadingShell
                }
            } else {
                plainThumbnailBubble
            }

            if showHoverRing {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .frame(width: diameter, height: diameter)
                    .allowsHitTesting(false)
            }

            if showNewBadge && isUnviewedAlbum {
                Text("new!")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(red: 0x12/255, green: 0x0c/255, blue: 0x0a/255))
                    .tracking(-0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 50)
                            .fill(Color(red: 0x67/255, green: 0x3f/255, blue: 0x2d/255))
                    )
                    .offset(x: -4, y: -4)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.15), value: showHoverRing)
        .onAppear { loadThumbnail() }
        .onChange(of: album.assets.count) { _ in loadThumbnail() }
        .onChange(of: album.coverAssetID) { _ in loadThumbnail() }
        .onChange(of: coverCacheKey) { _ in loadThumbnail() }
    }

    private var albumCoverLoadingShell: some View {
        ZStack {
            PeepholeGlassRimOverlay(
                outerDiameter: diameter,
                innerDiameter: innerDiameter,
                palette: .gallery
            )
        }
        .frame(width: diameter, height: diameter)
        .peepholeAlbumCircleGlow(isNew: isUnviewedAlbum, palette: .gallery)
    }

    @ViewBuilder
    private var plainThumbnailBubble: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())
                .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: innerDiameter, height: innerDiameter)
                .frame(width: diameter, height: diameter)
        }
    }

    private func loadThumbnail() {
        guard let asset = album.coverAsset else {
            thumbnail = nil
            loadedCoverKey = nil
            return
        }

        let key = coverCacheKey
        guard loadedCoverKey != key || thumbnail == nil else { return }

        loadedCoverKey = key
        let size = PhotoLibraryManager.coverThumbnailPixelSize(innerDiameter: innerDiameter)
        if let cached = library.cachedCoverThumbnail(for: asset, size: size) {
            thumbnail = cached
            return
        }

        thumbnail = nil
        library.coverThumbnail(for: asset, size: size) { image in
            guard coverCacheKey == key else { return }
            thumbnail = image
        }
    }
}

struct AlbumCircleCell: View {
    let album: DateAlbum
    let library: PhotoLibraryManager
    let diameter: CGFloat
    var showPeepholeEffect: Bool = true

    var body: some View {
        VStack(spacing: GalleryAlbumGridMetrics.thumbnailLabelSpacing) {
            AlbumCircleThumbnail(
                album: album,
                library: library,
                diameter: diameter,
                showPeepholeEffect: showPeepholeEffect
            )
            .id(album.galleryCoverViewID)
            AlbumCircleDateLabel(album: album, diameter: diameter)
        }
    }
}

// MARK: - Circular photo cell (used by AlbumDetailView)

struct CircularPhotoCell: View {
    let asset: PHAsset
    let library: PhotoLibraryManager
    let diameter: CGFloat
    var isNewest: Bool = false
    /// Peephole glass ring/glow — off by default; enable for album detail photo thumbnails only.
    var showPeepholeEffect: Bool = false

    @State private var thumbnail: UIImage?
    private var innerDiameter: CGFloat { diameter - 12 }
    private var label: String {
        PHAssetResource.assetResources(for: asset).first?.originalFilename ?? ""
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if showPeepholeEffect {
                    photoBubble
                        .peepholeAlbumCircleGlow(palette: .gallery, intensity: .photoThumbnail)

                    PeepholeGlassRimOverlay(
                        outerDiameter: diameter,
                        innerDiameter: innerDiameter,
                        palette: .gallery
                    )
                } else {
                    photoBubble
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
            .frame(width: diameter, height: diameter)

            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0xd4/255))
                .tracking(-0.6)
                .frame(width: diameter)
                .multilineTextAlignment(.center)
        }
        .onAppear { loadThumbnail() }
    }

    @ViewBuilder
    private var photoBubble: some View {
        if let img = thumbnail {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())
                .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: innerDiameter, height: innerDiameter)
                .frame(width: diameter, height: diameter)
        }
    }

    private func loadThumbnail() {
        let pt = innerDiameter
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
