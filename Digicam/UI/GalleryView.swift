// GalleryView.swift — replaced by GalleryRootView in Gallery/AlbumGridView.swift
// Shared layout helpers for the Memory Card / SD card flow live here.
import SwiftUI
import UIKit

// MARK: - Screen container

// Wraps SD card flow screens in a full-screen GeometryReader so every header can
// anchor to the real device safe area instead of using hardcoded offsets.
// Usage: SDCardScreenContainer { topPadding, bottomSafeInset in ... }
struct SDCardScreenContainer<Content: View>: View {
    @ViewBuilder let content: (_ topPadding: CGFloat, _ bottomSafeInset: CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, Self.keyWindowSafeAreaTop)
            content(max(16, topInset + 16), geometry.safeAreaInsets.bottom)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private static var keyWindowSafeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Sticky header

struct MemoryFlowHeaderBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MemoryFlowHeaderLayoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Toolbar-style header buttons (matches Edit Album Cancel/Save)

/// Text action in the Memory Flow custom header — same look as navigation-bar toolbar buttons.
struct MemoryFlowToolbarTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.white)
            .buttonStyle(.plain)
    }
}

/// Icon action in the Memory Flow custom header — same look as toolbar buttons.
struct MemoryFlowToolbarIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Back navigation

/// Tappable chevron + title group for Memory Flow detail screens.
struct MemoryFlowBackHeaderGroup: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(-1.2)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MemoryFlowSwipeBackExclusionFrameKey: PreferenceKey {
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue(), next != .zero {
            value = next
        }
    }
}

private struct MemoryFlowSwipeToGoBackModifier: ViewModifier {
    let horizontalThreshold: CGFloat
    let maxVerticalTranslation: CGFloat
    let excludesStartLocation: ((CGPoint) -> Bool)?
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if excludesStartLocation?(value.startLocation) == true { return }
                    guard value.translation.width > horizontalThreshold,
                          abs(value.translation.height) < maxVerticalTranslation else { return }
                    onBack()
                }
        )
    }
}

/// Disables NavigationStack's interactive pop so custom swipe-back owns the gesture.
struct DisableSystemPopGesture: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> _VC { _VC() }
    func updateUIViewController(_ vc: _VC, context: Context) {}

    final class _VC: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

extension View {
    /// Right-swipe anywhere on the screen to go back; does not block vertical scrolling.
    /// Use `excludesStartLocation` to opt regions out (e.g. a horizontal carousel).
    func memoryFlowSwipeToGoBack(
        horizontalThreshold: CGFloat = 80,
        maxVerticalTranslation: CGFloat = 60,
        excludesStartLocation: ((CGPoint) -> Bool)? = nil,
        onBack: @escaping () -> Void
    ) -> some View {
        modifier(MemoryFlowSwipeToGoBackModifier(
            horizontalThreshold: horizontalThreshold,
            maxVerticalTranslation: maxVerticalTranslation,
            excludesStartLocation: excludesStartLocation,
            onBack: onBack
        ))
    }

    /// Marks a view's bounds so `memoryFlowSwipeToGoBack` ignores drags that begin inside it.
    func memoryFlowSwipeBackExclusionFrame(in coordinateSpace: CoordinateSpace = .local) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MemoryFlowSwipeBackExclusionFrameKey.self,
                    value: geo.frame(in: coordinateSpace)
                )
            }
        )
    }

    /// Centered delete confirmation with scrim dismiss and a top-right close control.
    func memoryFlowDeleteConfirmation(
        _ title: String,
        isPresented: Binding<Bool>,
        deleteButtonTitle: String = "Delete",
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(MemoryFlowDeleteConfirmModifier(
            isPresented: isPresented,
            title: title,
            deleteButtonTitle: deleteButtonTitle,
            onDelete: onDelete
        ))
    }
}

// MARK: - Sticky header

/// Dark-to-clear gradient behind Memory Flow header chrome (content draws above this).
struct MemoryFlowHeaderScrim: View {
    /// How far the fade extends below the header text row.
    static let fadeExtension: CGFloat = 36

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: PeepholeVisualPalette.memoryFlowHeaderScrimTop, location: 0),
                .init(color: PeepholeVisualPalette.memoryFlowBackground.opacity(0.9), location: 0.38),
                .init(color: PeepholeVisualPalette.memoryFlowBackground.opacity(0.42), location: 0.72),
                .init(color: Color.clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .padding(.bottom, -Self.fadeExtension)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

/// Pinned header for Memory Flow screens: title row + optional subtitle.
struct MemoryFlowHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let topPadding: CGFloat
    var horizontalPadding: CGFloat = 20
    /// When true, the title is shown only inside `leading()` (e.g. `MemoryFlowBackHeaderGroup`).
    var hidesCenterTitle: Bool = false
    /// Set false when a parent wraps multiple chrome rows in a single `MemoryFlowHeaderScrim`.
    var appliesScrim: Bool = true
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    private let subtitleColor = Color(red: 0x82/255, green: 0x82/255, blue: 0x82/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                leading()
                if !hidesCenterTitle {
                    Text(title)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                        .tracking(-1.2)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                trailing()
            }
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(subtitleColor)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if appliesScrim {
                MemoryFlowHeaderScrim()
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: MemoryFlowHeaderLayoutHeightKey.self, value: geo.size.height)
                    .preference(
                        key: MemoryFlowHeaderBottomKey.self,
                        value: geo.frame(in: .global).maxY
                    )
            }
        )
    }
}

extension MemoryFlowHeader where Leading == EmptyView {
    init(
        title: String,
        subtitle: String,
        topPadding: CGFloat,
        horizontalPadding: CGFloat = 20,
        hidesCenterTitle: Bool = false,
        appliesScrim: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
        self.hidesCenterTitle = hidesCenterTitle
        self.appliesScrim = appliesScrim
        self.leading = { EmptyView() }
        self.trailing = trailing
    }
}

// MARK: - Glass selection controls

private enum MemoryFlowGlassStyle {
    /// Warm brown-gray glass fill — aligned with BottomToggle accent tones.
    static let fill = Color(red: 0x2a / 255, green: 0x23 / 255, blue: 0x20 / 255).opacity(0.48)
    static let warmTint = Color(red: 127 / 255, green: 104 / 255, blue: 96 / 255).opacity(0.22)
    static let border = Color.white.opacity(0.18)
    static let shadowColor = Color.black.opacity(0.38)
    static let iconActive = Color(white: 0.94)
    static let iconInactive = Color(white: 0.42)
    static let controlHeight: CGFloat = 54
}

private struct MemoryFlowGlassSurface<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(MemoryFlowGlassStyle.fill)
            shape.fill(MemoryFlowGlassStyle.warmTint)
        }
        .overlay {
            shape.strokeBorder(MemoryFlowGlassStyle.border, lineWidth: 0.75)
        }
        .shadow(color: MemoryFlowGlassStyle.shadowColor, radius: 10, x: 0, y: 5)
    }
}

/// Circular glass action button for album selection mode.
struct MemoryFlowGlassIconButton: View {
    let systemName: String
    var isEnabled: Bool = true
    let action: () -> Void

    private let diameter = MemoryFlowGlassStyle.controlHeight

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(isEnabled ? MemoryFlowGlassStyle.iconActive : MemoryFlowGlassStyle.iconInactive)
                .frame(width: diameter, height: diameter)
                .background {
                    MemoryFlowGlassSurface(shape: Circle())
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Glass pill showing how many photos are selected in album detail select mode.
struct MemoryFlowSelectionCountPill: View {
    let count: Int

    private var label: String {
        let noun = count == 1 ? "Photo" : "Photos"
        return "\(count) \(noun) Selected"
    }

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Color(white: 0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 18)
            .frame(height: MemoryFlowGlassStyle.controlHeight)
            .frame(minWidth: 168)
            .background {
                MemoryFlowGlassSurface(shape: Capsule())
            }
    }
}

// MARK: - Delete confirmation

private enum MemoryFlowDeleteConfirmStyle {
    static let scrim = Color.black.opacity(0.45)
    static let cardFill = Color(white: 0.16)
    static let cardBorder = Color.white.opacity(0.12)
    static let titleColor = Color.white
    static let separator = Color.white.opacity(0.12)
    static let destructive = Color.red
    static let cornerRadius: CGFloat = 14
    static let maxWidth: CGFloat = 270
}

private struct MemoryFlowDeleteConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let deleteButtonTitle: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                MemoryFlowDeleteConfirmOverlay(
                    title: title,
                    deleteButtonTitle: deleteButtonTitle,
                    onDismiss: { isPresented = false },
                    onDelete: {
                        isPresented = false
                        onDelete()
                    }
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isPresented)
    }
}

private struct MemoryFlowDeleteConfirmOverlay: View {
    let title: String
    let deleteButtonTitle: String
    let onDismiss: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MemoryFlowDeleteConfirmStyle.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(MemoryFlowDeleteConfirmStyle.titleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 16)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(white: 0.75))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                    .accessibilityLabel("Close")
                }

                MemoryFlowDeleteConfirmStyle.separator
                    .frame(height: 0.5)

                Button(action: onDelete) {
                    Text(deleteButtonTitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(MemoryFlowDeleteConfirmStyle.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: MemoryFlowDeleteConfirmStyle.maxWidth)
            .background(
                RoundedRectangle(cornerRadius: MemoryFlowDeleteConfirmStyle.cornerRadius, style: .continuous)
                    .fill(MemoryFlowDeleteConfirmStyle.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MemoryFlowDeleteConfirmStyle.cornerRadius, style: .continuous)
                    .strokeBorder(MemoryFlowDeleteConfirmStyle.cardBorder, lineWidth: 0.5)
            )
        }
    }
}
