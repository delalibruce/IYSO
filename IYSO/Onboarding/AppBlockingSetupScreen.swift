import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AppBlockingSetupScreen: View {
    @ObservedObject var appBlocking: AppBlockingManager
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showAddMore = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerText
                        defaultAppsSection
                        if showAddMore {
                            addMoreSection
                        } else {
                            addMoreToggleRow
                        }
                    }
                    .padding(.bottom, 120)
                }

                bottomButtons
            }
        }
        .task {
            if AppCapabilities.usesFamilyControls {
                await appBlocking.requestAuthorizationIfNeeded()
            }
            await AppIconResolver.shared.prefetch(apps: appBlocking.blockedApps)
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Put the distractions away")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("These apps are put away while IYSO mode is on. Change them any time in settings.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 28)
    }

    // MARK: - Default apps

    private var defaultAppsSection: some View {
        VStack(spacing: 0) {
            ForEach(appBlocking.blockedApps) { app in
                OnboardingAppRow(
                    app: app,
                    isEnabled: app.isEnabled,
                    onToggle: { appBlocking.toggleApp(app) }
                )
                if app.id != appBlocking.blockedApps.last?.id {
                    Divider()
                        .background(Color(white: 1, opacity: 0.08))
                        .padding(.leading, 24)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 1, opacity: 0.05))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Add more toggle

    private var addMoreToggleRow: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAddMore = true } }) {
            HStack {
                Text("Set up Screen Time shields")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.55))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.35))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add more section

    private var addMoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Screen Time shields")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.55))
                Spacer()
                Button(action: { withAnimation { showAddMore = false } }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            FamilyControlsSetupPanel(compact: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Bottom

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            OnboardingContinueButton(action: onContinue)

            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        )
    }
}
private struct OnboardingAppRow: View {
    let app: BlockedApp
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BlockedAppIconView(app: app)

            Text(app.name)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: Binding(get: { isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

