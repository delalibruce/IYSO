import AVFoundation

/// Single-use delegate that handles one AVCapturePhoto result.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            print("[Digicam] Capture error: \(error)")
            completion(nil)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            print("[Digicam] Failed to read photo data representation")
            completion(nil)
            return
        }

        completion(data)
    }
}
