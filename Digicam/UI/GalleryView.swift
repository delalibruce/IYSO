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

/// Pinned header for Memory Flow screens: title row + optional subtitle.
struct MemoryFlowHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let topPadding: CGFloat
    var horizontalPadding: CGFloat = 20
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    private let backgroundColor = Color(red: 0x1e/255, green: 0x13/255, blue: 0x0f/255)
    private let subtitleColor = Color(red: 0x82/255, green: 0x82/255, blue: 0x82/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                leading()
                Text(title)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(-1.2)
                    .lineLimit(1)
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
