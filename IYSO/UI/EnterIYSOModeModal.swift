import SwiftUI

struct EnterIYSOModeModal: View {
    let onEnter: () -> Void
    let onCancel: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                Spacer()
                sheet
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var sheet: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Ready to enter IYSO mode?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("Stay focused on taking pictures in the moment.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                shieldAnimation

                Button(action: onEnter) {
                    Text("Start shooting")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.18, green: 0.55, blue: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Take me back to memory card")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(white: 0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(white: 1, opacity: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.82)
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

    private var shieldAnimation: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(pulseOpacity), lineWidth: 3)
                .frame(width: 88, height: 88)
                .scaleEffect(pulseScale)

            Circle()
                .stroke(Color(red: 0.18, green: 0.55, blue: 1.0).opacity(0.35), lineWidth: 1.5)
                .frame(width: 108, height: 108)
                .scaleEffect(pulseScale)

            Image(systemName: "camera.fill")
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
        }
    }
}
