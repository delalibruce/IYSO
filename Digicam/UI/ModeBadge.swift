import SwiftUI
import UIKit

/// Shared placement for root tab headers (Memory Card grid + Camera).
enum RootTabHeaderLayout {
    static let horizontalPadding: CGFloat = 20
    static let modeLabelToTitleSpacing: CGFloat = 6

    /// Matches `SDCardScreenContainer` — distance from the physical screen top to the mode label.
    static func topPadding(geometrySafeAreaTop: CGFloat) -> CGFloat {
        max(16, max(geometrySafeAreaTop, keyWindowSafeAreaTop) + 16)
    }

    static var keyWindowSafeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

enum AppMode {
    case iyso, memory

    var label: String {
        switch self {
        case .iyso:   return "IYSO Mode"
        case .memory: return "Memory Mode"
        }
    }
}

struct ModeBadge: View {
    let mode: AppMode

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0x00/255, green: 0xdf/255, blue: 0x4f/255))
                .frame(width: 6, height: 6)
            Text(mode.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(white: 1, opacity: 0.05))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(white: 1, opacity: 0.10), lineWidth: 0.5)
                )
        )
    }
}
