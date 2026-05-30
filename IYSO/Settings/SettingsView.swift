import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerText
                        BlockedAppsSelectionPanel()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await appBlocking.requestAuthorizationIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("App Shields")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var headerText: some View {
        Text("Choose apps you want to block while you shoot.")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 28)
    }
}
