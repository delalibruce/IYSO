import SwiftUI

struct NFCCalibrationScreen: View {
    @ObservedObject var nfc: NFCManager
    let onLensConnected: () -> Void
    let onSkip: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 44) {
                    VStack(spacing: 12) {
                        Text("One last thing.")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Attach your lens clip near the top of your iPhone to connect it.")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(white: 0.55))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 30)

                    nfcAnimation
                }

                Spacer()

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .onAppear {
            startPulse()
            if nfc.isNFCAvailable {
                nfc.startScanning()
            }
        }
        .onDisappear {
            nfc.cancelScanning()
        }
        .onChange(of: nfc.scanState) { state in
            if state == .detected {
                onLensConnected()
            }
        }
    }

    // MARK: - Animation

    private var nfcAnimation: some View {
        ZStack {
            switch nfc.scanState {
            case .detected:
                detectedView
            case .wrongTag:
                wrongTagView
            case .unavailable:
                unavailableView
            default:
                scanningView
            }
        }
        .frame(width: 160, height: 160)
    }

    private var scanningView: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(pulseOpacity), lineWidth: 2.5)
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)

            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(pulseOpacity * 0.5), lineWidth: 1.5)
                .frame(width: 148, height: 148)
                .scaleEffect(pulseScale)

            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
        }
    }

    private var detectedView: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.0, green: 0.55, blue: 0.3, opacity: 0.2))
                .frame(width: 120, height: 120)

            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(Color(red: 0, green: 0.85, blue: 0.4))
        }
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var wrongTagView: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.red)

                Text("Try again")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.6))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if nfc.isNFCAvailable { nfc.startScanning() }
            }
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Color(white: 0.45))

            Text("NFC isn't available on this device.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bottom

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if nfc.scanState == .unavailable {
                Button(action: onSkip) {
                    Text("Continue without lens")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: onSkip) {
                Text("I don't have my lens yet")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.4))
            }
            .buttonStyle(.plain)

            #if targetEnvironment(simulator)
            Button(action: { nfc.simulateDetect() }) {
                Text("Simulate Detect (Simulator)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.18, green: 0.55, blue: 1.0))
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
            pulseOpacity = 1.0
        }
    }
}
