import AVFoundation
import UIKit

/// Single-use delegate that handles one AVCapturePhoto result.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
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

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            print("[Digicam] Failed to decode photo data")
            completion(nil)
            return
        }

        completion(image)
    }
}
