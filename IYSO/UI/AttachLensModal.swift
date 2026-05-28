import SwiftUI

struct AttachLensModal: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var nfc: NFCManager

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()
                sheet
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var sheet: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Attach lens to shoot")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("attach or reattach lens")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
            }

            lensAnimation

            Button(action: dismiss) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(white: 0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(white: 1, opacity: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            #if DEBUG
            Button(action: bypassForDevelopment) {
                Text("Developer Bypass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0x12/255, green: 0x10/255, blue: 0x0f/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(white: 1, opacity: 0.10), lineWidth: 0.5)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var lensAnimation: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(pulseOpacity), lineWidth: 3)
                .frame(width: 88, height: 88)
                .scaleEffect(pulseScale)

            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(0.35), lineWidth: 1.5)
                .frame(width: 108, height: 108)
                .scaleEffect(pulseScale)

            Image(systemName: "iphone")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
                pulseOpacity = 1.0
            }
            if AppCapabilities.usesNFC {
                nfc.startScanning()
            }
        }
        .onDisappear {
            if AppCapabilities.usesNFC {
                nfc.cancelScanning()
            }
        }
    }

    private func dismiss() {
        appState.showAttachLensSheet = false
        if AppCapabilities.usesNFC {
            nfc.cancelScanning()
        }
    }

    #if DEBUG
    private func bypassForDevelopment() {
        nfc.simulateDetect()
        dismiss()
    }
    #endif
}
