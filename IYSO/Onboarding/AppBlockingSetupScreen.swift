import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

struct AppBlockingSetupScreen: View {
    @ObservedObject var appBlocking: AppBlockingManager
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var showAddMore = false
    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerText
                        blockedAppsSection
                        chooseAppsButton
                            .padding(.top, 16)
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

    // MARK: - Header

    private var headerText: some View {
        Text("choose apps you want to block while you shoot.")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 28)
    }

    // MARK: - Blocked apps list

    private var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current blocked apps")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(white: 0.55))
                .padding(.horizontal, 24)

            if hasBlockedItems {
                VStack(spacing: 0) {
                    #if canImport(FamilyControls)
                    if AppCapabilities.usesFamilyControls, appBlocking.selectedItemCount > 0 {
                        familySelectedRows
                    } else {
                        defaultBlockedAppRows
                    }
                    #else
                    defaultBlockedAppRows
                    #endif
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 1, opacity: 0.05))
                )
                .padding(.horizontal, 20)
            } else {
                Text("No apps blocked yet.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
                    .padding(.horizontal, 24)
            }
        }
    }

    private var chooseAppsButton: some View {
        #if canImport(FamilyControls)
        Group {
            if AppCapabilities.usesFamilyControls {
                Button(action: { showFamilyActivityPicker = true }) {
                    HStack {
                        Text("Choose apps to block")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                        Spacer()
                        Text(selectionSummary)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(white: 0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 1, opacity: 0.05))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        #else
        EmptyView()
        #endif
    }

    private var enabledDefaultApps: [BlockedApp] {
        appBlocking.blockedApps.filter(\.isEnabled)
    }

    private var hasBlockedItems: Bool {
        #if canImport(FamilyControls)
        if AppCapabilities.usesFamilyControls, appBlocking.selectedItemCount > 0 {
            return true
        }
        #endif
        return !enabledDefaultApps.isEmpty
    }

    #if canImport(FamilyControls)
    private var selectionSummary: String {
        let screenTimeCount = appBlocking.selectedItemCount
        if screenTimeCount > 0 {
            return "\(screenTimeCount) selected"
        }
        let defaultCount = enabledDefaultApps.count
        return defaultCount == 0 ? "None selected" : "\(defaultCount) selected"
    }

    @ViewBuilder
    private var defaultBlockedAppRows: some View {
        ForEach(enabledDefaultApps) { app in
            OnboardingDefaultBlockedAppRow(app: app)
            if app.id != enabledDefaultApps.last?.id {
                listDivider
            }
        }
    }

    @ViewBuilder
    private var familySelectedRows: some View {
        let apps = Array(appBlocking.familyActivitySelection.applicationTokens)
        let categories = Array(appBlocking.familyActivitySelection.categoryTokens)
        let domains = Array(appBlocking.familyActivitySelection.webDomainTokens)

        ForEach(apps, id: \.self) { token in
            OnboardingFamilyActivityRow(token: token)
            if token != apps.last || !categories.isEmpty || !domains.isEmpty {
                listDivider
            }
        }

        ForEach(categories, id: \.self) { token in
            OnboardingFamilyActivityRow(categoryToken: token)
            if token != categories.last || !domains.isEmpty {
                listDivider
            }
        }

        ForEach(domains, id: \.self) { token in
            OnboardingFamilyActivityRow(webDomainToken: token)
            if token != domains.last {
                listDivider
            }
        }
    }
    #endif

    private var listDivider: some View {
        Divider()
            .background(Color(white: 1, opacity: 0.08))
            .padding(.leading, 24)
    }

    // MARK: - Add more toggle

    private var addMoreToggleRow: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showAddMore = true } }) {
            HStack {
                Text("Are there any more apps you want to block?")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Are there any more apps you want to block?")
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

            chooseAppsButton
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

private struct OnboardingDefaultBlockedAppRow: View {
    let app: BlockedApp

    var body: some View {
        HStack(spacing: 14) {
            BlockedAppIconView(app: app)

            Text(app.name)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

#if canImport(FamilyControls)
private struct OnboardingFamilyActivityRow: View {
    enum TokenKind {
        case application(ApplicationToken)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)
    }

    private let kind: TokenKind

    init(token: ApplicationToken) {
        kind = .application(token)
    }

    init(categoryToken: ActivityCategoryToken) {
        kind = .category(categoryToken)
    }

    init(webDomainToken: WebDomainToken) {
        kind = .webDomain(webDomainToken)
    }

    var body: some View {
        HStack(spacing: 14) {
            iconLabel
                .labelStyle(.iconOnly)
                .frame(width: 36, height: 36)

            titleLabel
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var iconLabel: some View {
        switch kind {
        case .application(let token):
            Label(token)
        case .category(let token):
            Label(token)
        case .webDomain(let token):
            Label(token)
        }
    }

    @ViewBuilder
    private var titleLabel: some View {
        switch kind {
        case .application(let token):
            Label(token)
        case .category(let token):
            Label(token)
        case .webDomain(let token):
            Label(token)
        }
    }
}
#endif
