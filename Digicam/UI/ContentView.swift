import SwiftUI

private enum CameraLayout {
    /// Gap from top of screen to top of the fisheye preview circle.
    static let previewTopInset: CGFloat = 72
    /// Gap from bottom of screen to bottom of the shutter button (sits above the tab toggle).
    static let shutterBottomInset: CGFloat = 140
}

struct CameraView: View {
    @ObservedObject var camera: CameraManager

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()
                fisheyeCircle(diameter: geo.size.width)
                    .padding(.top, CameraLayout.previewTopInset)
                VStack {
                    Spacer()
                    shutterButton
                        .padding(.bottom, CameraLayout.shutterBottomInset)
                }
            }
        }
    }

    // MARK: - Fisheye circle preview

    private func fisheyeCircle(diameter: CGFloat) -> some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .clipShape(Circle())
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(
                    RadialGradient(
                        colors: [Color.black.opacity(0.55), Color.clear],
                        center: .center,
                        startRadius: diameter * 0.38,
                        endRadius: diameter * 0.5
                    ),
                    lineWidth: diameter * 0.08
                )
                .frame(width: diameter, height: diameter)
        }
    }

    // MARK: - Shutter

    private var shutterButton: some View {
        Button(action: { camera.capturePhoto() }) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 3)
                    .frame(width: 82, height: 82)
                Circle()
                    .fill(Color.white)
                    .frame(width: 68, height: 68)
            }
        }
        .disabled(!camera.isSessionRunning)
    }
}
