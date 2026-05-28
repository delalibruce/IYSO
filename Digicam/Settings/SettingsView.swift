import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct SettingsView: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager
    @Environment(\.dismiss) private var dismiss
    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    #endif

    var body: some View {
        ZStack {
            PeepholeVisualPalette.memoryFlowBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader
                        additionalControls
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

    private var additionalControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if canImport(FamilyControls)
            Button(action: { showFamilyActivityPicker = true }) {
                HStack {
                    Text("Choose apps/categories")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                    Spacer()
                    Text("\(appBlocking.selectedItemCount) selected")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(white: 0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(white: 1, opacity: 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

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
        #if canImport(FamilyControls)
        .familyActivityPicker(
            isPresented: $showFamilyActivityPicker,
            selection: Binding(
                get: { appBlocking.familyActivitySelection },
                set: { appBlocking.updateFamilyActivitySelection($0) }
            )
        )
        #endif
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
