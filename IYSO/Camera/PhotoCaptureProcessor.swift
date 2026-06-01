import AVFoundation

/// Single-use delegate that handles one AVCapturePhoto result.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    let settingsUniqueID: Int64
    private let photoDataHandler: (Data?) -> Void
    private let completionHandler: () -> Void
    private var hasDeliveredPhotoData = false
    private var hasFinishedCapture = false

    init(settingsUniqueID: Int64,
         photoDataHandler: @escaping (Data?) -> Void,
         completionHandler: @escaping () -> Void) {
        self.settingsUniqueID = settingsUniqueID
        self.photoDataHandler = photoDataHandler
        self.completionHandler = completionHandler
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            print("[Digicam] Capture error: \(error)")
            deliverPhotoData(nil)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            print("[Digicam] Failed to read photo data representation")
            deliverPhotoData(nil)
            return
        }

        deliverPhotoData(data)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error {
            print("[Digicam] Capture finished with error: \(error)")
            deliverPhotoData(nil)
        }
        finishCapture()
    }

    private func deliverPhotoData(_ data: Data?) {
        guard !hasDeliveredPhotoData else { return }
        hasDeliveredPhotoData = true
        photoDataHandler(data)
    }

    private func finishCapture() {
        guard !hasFinishedCapture else { return }
        hasFinishedCapture = true
        completionHandler()
    }
}
