import SwiftUI

private enum CameraLayout {
    static let previewTopInset: CGFloat = 152
    static let shutterBottomInset: CGFloat = 156
}

struct CameraView: View {
    @ObservedObject var camera: CameraManager
    @EnvironmentObject private var appState: AppState

    var onExitIYSOTapped: (() -> Void)?
    private let shutterButtonSize: CGFloat = 82

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
            HStack(alignment: .center) {
                ModeBadge(mode: .iyso)
                Spacer(minLength: 0)
                if appState.isIYSOMode {
                    exitButton
                }
            }
            .padding(.horizontal, RootTabHeaderLayout.horizontalPadding)
            .padding(.top, topPadding)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.22), value: appState.isIYSOMode)
    }

    private var exitButton: some View {
        Button(action: { onExitIYSOTapped?() }) {
            ExitIYSOModeButton()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fisheye circle preview

    private func fisheyeCircle(diameter: CGFloat) -> some View {
        ZStack {
            if camera.isCaptureReady {
                CameraPreviewView(session: camera.session)
                    .clipShape(Circle())
                    .frame(width: diameter, height: diameter)
                    .transition(.opacity)
            } else {
                Circle()
                    .fill(Color.black)
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.035))
                            .padding(diameter * 0.08)
                    )
            }

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
        .animation(.easeInOut(duration: 0.18), value: camera.isCaptureReady)
    }

    // MARK: - Shutter

    private var shutterButton: some View {
        Button(action: { camera.capturePhoto() }) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 3)
                    .frame(width: 82, height: 82)
                Circle()
                    .fill(camera.isCaptureReady ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 68, height: 68)
            }
        }
        .disabled(!camera.isCaptureReady)
    }
}
