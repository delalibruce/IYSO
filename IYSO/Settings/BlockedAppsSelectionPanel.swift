import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

/// Shared blocked-apps picker UI (onboarding, settings, IYSO mode modal).
struct BlockedAppsSelectionPanel: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager

    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasScreenTimeSelections {
                Text("Current blocked apps")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.55))
                    .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    #if canImport(FamilyControls)
                    familySelectedRows
                    #endif
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 1, opacity: 0.05))
                )
                .padding(.horizontal, 20)

                chooseMoreAppsButton
                    .padding(.top, 4)
            } else {
                emptyState
            }
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No apps blocked yet.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .frame(maxWidth: .infinity, alignment: .leading)

            #if canImport(FamilyControls)
            if AppCapabilities.usesFamilyControls {
                Button(action: { showFamilyActivityPicker = true }) {
                    Text("Choose apps to block")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(white: 1, opacity: 0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .padding(.horizontal, 20)
    }

    private var chooseMoreAppsButton: some View {
        #if canImport(FamilyControls)
        Group {
            if AppCapabilities.usesFamilyControls {
                Button(action: { showFamilyActivityPicker = true }) {
                    HStack {
                        Text("Choose more apps to block")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                        Spacer()
                        Text("\(appBlocking.selectedItemCount) selected")
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

    private var hasScreenTimeSelections: Bool {
        #if canImport(FamilyControls)
        return AppCapabilities.usesFamilyControls && appBlocking.selectedItemCount > 0
        #else
        return false
        #endif
    }

    #if canImport(FamilyControls)
    @ViewBuilder
    private var familySelectedRows: some View {
        let apps = Array(appBlocking.familyActivitySelection.applicationTokens)
        let categories = Array(appBlocking.familyActivitySelection.categoryTokens)
        let domains = Array(appBlocking.familyActivitySelection.webDomainTokens)

        ForEach(apps, id: \.self) { token in
            FamilyActivitySelectionRow(token: token)
            if token != apps.last || !categories.isEmpty || !domains.isEmpty {
                selectionListDivider
            }
        }

        ForEach(categories, id: \.self) { token in
            FamilyActivitySelectionRow(categoryToken: token)
            if token != categories.last || !domains.isEmpty {
                selectionListDivider
            }
        }

        ForEach(domains, id: \.self) { token in
            FamilyActivitySelectionRow(webDomainToken: token)
            if token != domains.last {
                selectionListDivider
            }
        }
    }
    #endif

    private var selectionListDivider: some View {
        Divider()
            .background(Color(white: 1, opacity: 0.08))
            .padding(.leading, 24)
    }
}

#if canImport(FamilyControls)
struct FamilyActivitySelectionRow: View {
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
            rowLabel
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
    private var rowLabel: some View {
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
