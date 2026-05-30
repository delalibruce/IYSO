import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AppBlockingSettingsView: View {
    @EnvironmentObject private var appBlocking: AppBlockingManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
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

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Pick the apps and categories IYSO should shield while you're in camera mode. Changes apply the next time IYSO Mode turns on.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(white: 0.55))
                            .fixedSize(horizontal: false, vertical: true)

                        FamilyControlsSetupPanel()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await appBlocking.requestAuthorizationIfNeeded()
        }
    }
}
