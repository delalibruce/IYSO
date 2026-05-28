import SwiftUI
import AVFoundation

/// Bridges AVCaptureVideoPreviewLayer into SwiftUI.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> _PreviewView {
        let view = _PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: _PreviewView, context: Context) {}
}

/// UIView subclass whose backing layer is AVCaptureVideoPreviewLayer.
final class _PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe: layerClass guarantees this cast
        layer as! AVCaptureVideoPreviewLayer
    }
}
