import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @State private var showGallery = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Controls row — shutter centered, thumbnail right
                ZStack(alignment: .center) {
                    shutterButton

                    HStack {
                        Spacer()
                        thumbnail
                            .padding(.trailing, 28)
                    }
                }
                .padding(.bottom, 52)
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            camera.requestPermissionsAndStart()
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView(images: camera.capturedImages, isPresented: $showGallery)
        }
    }

    // MARK: - Subviews

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

    @ViewBuilder
    private var thumbnail: some View {
        if let image = camera.lastCapturedImage {
            Button(action: { showGallery = true }) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipped()
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
        } else {
            Color.clear.frame(width: 58, height: 58)
        }
    }
}
