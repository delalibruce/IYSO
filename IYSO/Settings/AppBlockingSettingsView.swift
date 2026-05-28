import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AppBlockingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    #if canImport(FamilyControls)
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    #endif

    var body: some View {
        VStack(spacing: 24) {
            Text("Block during camera mode")
                .font(.headline)

            Text("These apps will be hidden while IYSO Mode is active.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if canImport(FamilyControls)
            Button("Choose apps") {
                showPicker = true
            }
            .buttonStyle(.borderedProminent)

            let count = selection.applicationTokens.count
                + selection.categoryTokens.count
                + selection.webDomainTokens.count
            if count > 0 {
                Text("\(count) apps selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #else
            Text("App blocking is not available in this build.")
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif

            Button("Done") { dismiss() }
        }
        .padding()
        #if canImport(FamilyControls)
        .sheet(isPresented: $showPicker) {
            FamilyActivityPicker(selection: $selection)
        }
        .onAppear {
            if let saved = AppBlockingManager.shared.loadBlockList() {
                selection = saved
            }
        }
        .onChange(of: selection) { newSelection in
            AppBlockingManager.shared.saveBlockList(newSelection)
        }
        #endif
    }
}
