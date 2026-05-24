import SwiftUI

/// Global frames for album grid photo cells (used for pull-down hero dismiss).
struct PhotoGridFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct PhotoLayoutFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

extension View {
    func reportsPhotoLayoutFrame(in space: CoordinateSpace = .global) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PhotoLayoutFrameKey.self,
                    value: geo.frame(in: space)
                )
            }
        )
    }

    func onPhotoLayoutFrameChange(_ handler: @escaping (CGRect) -> Void) -> some View {
        onPreferenceChange(PhotoLayoutFrameKey.self, perform: handler)
    }
}
