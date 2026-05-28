import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PeepholeVisualPalette.memoryFlowBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader
                        appList
                    }
                    .padding(.bottom, 40)
                }
            }
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

            Text("Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Section

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Block during IYSO Mode")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("These apps will be put away while IYSO Mode is active. Change them any time.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - App toggles

    private var appList: some View {
        VStack(spacing: 0) {
            ForEach(appBlocking.blockedApps) { app in
                AppBlockingRow(app: app) {
                    if !appBlocking.isAuthorized {
                        Task { await appBlocking.requestAuthorizationIfNeeded() }
                    }
                    appBlocking.toggleApp(app)
                }

                if app.id != appBlocking.blockedApps.last?.id {
                    Divider()
                        .background(Color(white: 1, opacity: 0.08))
                        .padding(.leading, 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 1, opacity: 0.05))
        )
        .padding(.horizontal, 20)
    }
}

private struct AppBlockingRow: View {
    let app: BlockedApp
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BlockedAppIconView(app: app)

            Text(app.name)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: Binding(
                get: { app.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
