import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

/// Shared Screen Time / Family Controls setup used in Settings, onboarding, and modals.
struct FamilyControlsSetupPanel: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager
    var showsAuthorizationStatus: Bool = true
    var compact: Bool = false

    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            if showsAuthorizationStatus {
                authorizationStatus
            }

            #if canImport(FamilyControls)
            if AppCapabilities.usesFamilyControls {
                chooseAppsButton
                if let error = appBlocking.lastShieldError, appBlocking.shieldsShouldBeActive {
                    Text(error)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(red: 1, green: 0.45, blue: 0.45))
                } else if appBlocking.selectedItemCount == 0 {
                    Text("Pick at least one app — blocking only works for apps selected here.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(white: 0.45))
                }
            } else {
                Text("Family Controls are unavailable in this build.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
            }
            #else
            Text("Family Controls require iOS 16 or later.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(white: 0.45))
            #endif
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

    @ViewBuilder
    private var authorizationStatus: some View {
        if !AppCapabilities.usesFamilyControls {
            EmptyView()
        } else if appBlocking.isAuthorized {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                Text("Screen Time access allowed")
                    .font(.system(size: compact ? 13 : 14, weight: .medium))
                    .foregroundColor(Color(white: 0.75))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow Screen Time access so IYSO can shield apps during shooting.")
                    .font(.system(size: compact ? 13 : 14, weight: .regular))
                    .foregroundColor(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: requestAuthorization) {
                    Text("Allow Screen Time access")
                        .font(.system(size: compact ? 14 : 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 12 : 14)
                        .background(Color(red: 0.18, green: 0.55, blue: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var chooseAppsButton: some View {
        Button(action: { showFamilyActivityPicker = true }) {
            HStack {
                Text("Choose apps to block")
                    .font(.system(size: compact ? 14 : 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                Spacer()
                Text(appBlocking.selectedItemCount == 0 ? "None selected" : "\(appBlocking.selectedItemCount) selected")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 11 : 13)
            .background(Color(white: 1, opacity: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func requestAuthorization() {
        Task { await appBlocking.requestAuthorizationIfNeeded() }
    }
}
