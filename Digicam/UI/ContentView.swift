import SwiftUI

private enum CameraLayout {
    static let previewTopInset: CGFloat = 152
    static let shutterBottomInset: CGFloat = 140
}

struct CameraView: View {
    @ObservedObject var camera: CameraManager
    @EnvironmentObject private var appState: AppState

    var onExitIYSOTapped: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            let topPadding = RootTabHeaderLayout.topPadding(geometrySafeAreaTop: geo.safeAreaInsets.top)

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                fisheyeCircle(diameter: geo.size.width)
                    .padding(.top, CameraLayout.previewTopInset)

                VStack {
                    Spacer()
                    shutterButton
                        .padding(.bottom, CameraLayout.shutterBottomInset)
                }

                cameraChrome(topPadding: topPadding)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Chrome overlay (mode label + exit button + banner)

    private func cameraChrome(topPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: RootTabHeaderLayout.modeLabelToTitleSpacing) {
                ModeBadge(mode: .iyso)

                HStack {
                    Spacer(minLength: 0)
                    if appState.isIYSOMode {
                        exitButton
                    }
                }
            }
            .padding(.horizontal, RootTabHeaderLayout.horizontalPadding)
            .padding(.top, topPadding)

            if appState.showLensDetectedBanner {
                LensDetectedBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.22), value: appState.showLensDetectedBanner)
        .animation(.easeInOut(duration: 0.22), value: appState.isIYSOMode)
    }

    private var exitButton: some View {
        Button(action: { onExitIYSOTapped?() }) {
            Text("Exit IYSO Mode")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(white: 1, opacity: 0.12))
                        .overlay(Capsule().strokeBorder(Color(white: 1, opacity: 0.2), lineWidth: 0.5))
                )
        }
        .buttonStyle(.plain)
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
