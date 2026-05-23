// GalleryView.swift — replaced by GalleryRootView in Gallery/AlbumGridView.swift
// Shared layout helpers for the Memory Card / SD card flow live here.
import SwiftUI
import UIKit

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
