import SwiftUI
import Photos

struct PhotoFileNameEditView: View {
    let asset: PHAsset
    @ObservedObject var library: PhotoLibraryManager

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool
    @State private var fileNameText: String

    init(asset: PHAsset, library: PhotoLibraryManager) {
        self.asset = asset
        self.library = library
        _fileNameText = State(initialValue: library.photoDisplayName(for: asset))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PeepholeVisualPalette.memoryFlowBackground.ignoresSafeArea()

                TextField("", text: $fileNameText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { save() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.12))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Edit File Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundColor(.white)
                        .disabled(fileNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFieldFocused = true
                }
            }
        }
        .presentationDetents([.height(168)])
    }

    private func save() {
        let trimmed = fileNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed != library.photoDisplayName(for: asset) {
            library.updatePhotoFileName(assetLocalID: asset.localIdentifier, fileName: trimmed)
        }
        dismiss()
    }
}
