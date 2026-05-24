// GalleryView.swift — replaced by GalleryRootView in Gallery/AlbumGridView.swift
// Shared layout helpers for the Memory Card / SD card flow live here.
import SwiftUI
import UIKit

// MARK: - Screen container

// Wraps SD card flow screens in a full-screen GeometryReader so every header can
// anchor to the real device safe area instead of using hardcoded offsets.
// Usage: SDCardScreenContainer { topPadding in ... }
struct SDCardScreenContainer<Content: View>: View {
    @ViewBuilder let content: (_ topPadding: CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, Self.keyWindowSafeAreaTop)
            content(max(16, topInset + 16))
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

private struct MemoryFlowSwipeToGoBackModifier: ViewModifier {
    let horizontalThreshold: CGFloat
    let maxVerticalTranslation: CGFloat
    let onBack: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
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
    func memoryFlowSwipeToGoBack(
        horizontalThreshold: CGFloat = 80,
        maxVerticalTranslation: CGFloat = 60,
        onBack: @escaping () -> Void
    ) -> some View {
        modifier(MemoryFlowSwipeToGoBackModifier(
            horizontalThreshold: horizontalThreshold,
            maxVerticalTranslation: maxVerticalTranslation,
            onBack: onBack
        ))
    }
}

// MARK: - Sticky header

/// Pinned header for Memory Flow screens: title row + optional subtitle.
struct MemoryFlowHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let topPadding: CGFloat
    var horizontalPadding: CGFloat = 20
    /// When true, the title is shown only inside `leading()` (e.g. `MemoryFlowBackHeaderGroup`).
    var hidesCenterTitle: Bool = false
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    private let backgroundColor = PeepholeVisualPalette.memoryFlowBackground
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
        .background(
            backgroundColor
                .ignoresSafeArea(edges: .top)
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
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
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.topPadding = topPadding
        self.horizontalPadding = horizontalPadding
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
