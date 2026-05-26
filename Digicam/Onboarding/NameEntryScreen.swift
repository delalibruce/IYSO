import SwiftUI

struct NameEntryScreen: View {
    @Binding var name: String
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    Text("What's your name?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    TextField("your name", text: $name)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .tint(.white)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if canContinue { onContinue() }
                        }
                        .padding(.vertical, 14)
                        .overlay(
                            Rectangle()
                                .fill(Color(white: 1, opacity: 0.25))
                                .frame(height: 1),
                            alignment: .bottom
                        )
                        .padding(.horizontal, 40)
                }

                Spacer()

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onAppear { isFocused = true }
    }

    private var continueButton: some View {
        Button(action: {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            name = trimmed
            onContinue()
        }) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(canContinue ? .black : Color(white: 0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canContinue ? Color.white : Color(white: 1, opacity: 0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .animation(.easeInOut(duration: 0.15), value: canContinue)
    }
}
