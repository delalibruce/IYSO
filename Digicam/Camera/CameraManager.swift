import AVFoundation
import Photos
import UIKit

class CameraManager: NSObject, ObservableObject {

    // MARK: - Public state

    let session = AVCaptureSession()
    @Published var isSessionRunning = false

    // MARK: - Private

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var activeCaptureProcessor: PhotoCaptureProcessor?
    private var isConfigured = false

    // MARK: - Session lifecycle

    func startSession() {
        #if DEBUG
        if DebugOverrides.forceDeniedCamera || DebugOverrides.suppressPermissionPrompts {
            print("[Digicam] Debug: suppressing camera permission prompt/session start")
            return
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureIfNeededAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else {
                    print("[Digicam] Camera permission denied")
                    return
                }
                self.sessionQueue.async { self.configureIfNeededAndStart() }
            }
        default:
            print("[Digicam] Camera access not available")
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Session setup

    private func configureIfNeededAndStart() {
        if !isConfigured {
            configureSession()
            isConfigured = true
        }

        guard !session.isRunning else {
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
            return
        }

        session.startRunning()

        DispatchQueue.main.async {
            self.isSessionRunning = self.session.isRunning
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = discoverUltraWideCamera() else {
            print("[Digicam] No camera device found")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                print("[Digicam] Cannot add camera input")
                session.commitConfiguration()
                return
            }
            session.addInput(input)
        } catch {
            print("[Digicam] Device input error: \(error)")
            session.commitConfiguration()
            return
        }

        // Prefer speed over quality to reduce computational photography pipeline
        photoOutput.maxPhotoQualityPrioritization = .speed

        guard session.canAddOutput(photoOutput) else {
            print("[Digicam] Cannot add photo output")
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)

        session.commitConfiguration()

        // Device configuration must happen after session is committed
        configureDevice(device)
    }

    private func discoverUltraWideCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: .back
        )

        if let device = discovery.devices.first {
            print("[Digicam] Camera: \(device.localizedName)")
            return device
        }

        // Simulator fallback — physical device should always find the ultra-wide
        print("[Digicam] Ultra-wide not found, falling back to default (simulator?)")
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Manual device configuration

    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            // Zoom: 1.0 on the ultra-wide = 0.5x equivalent — no digital zoom
            device.videoZoomFactor = 1.0

            // Focus: locked at infinity (lensPosition 1.0 = farthest)
            if device.isFocusModeSupported(.locked) {
                device.setFocusModeLocked(lensPosition: 1.0) { _ in
                    print("[Digicam] Focus locked — lensPosition=1.0")
                }
            } else {
                print("[Digicam] Locked focus not supported on this device")
            }

            // White balance: locked (prevent auto-adaptation)
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

            // Exposure: manual ISO 54, shutter 1/125s — clamped to hardware limits
            if device.isExposureModeSupported(.custom) {
                let requestedISO: Float = 54.0
                let requestedDuration = CMTime(value: 1, timescale: 125)

                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let clampedISO = min(max(requestedISO, minISO), maxISO)

                let minDuration = device.activeFormat.minExposureDuration
                let maxDuration = device.activeFormat.maxExposureDuration
                let clampedDuration = CMTimeClamped(requestedDuration,
                                                    min: minDuration,
                                                    max: maxDuration)

                print("[Digicam] ISO range \(minISO)–\(maxISO) → applying \(clampedISO)")
                print("[Digicam] Duration range \(minDuration.seconds)s–\(maxDuration.seconds)s → applying \(clampedDuration.seconds)s")

                device.setExposureModeCustom(duration: clampedDuration, iso: clampedISO) { _ in
                    print("[Digicam] Exposure configured")
                }
            } else {
                print("[Digicam] Custom exposure not supported on this device")
            }

        } catch {
            print("[Digicam] Device configuration error: \(error)")
        }
    }

    // MARK: - Photo capture

    func capturePhoto() {
        guard isSessionRunning else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let settings = AVCapturePhotoSettings()

            // Flash always on
            if self.photoOutput.supportedFlashModes.contains(.on) {
                settings.flashMode = .on
            } else {
                print("[Digicam] Flash not supported on this device/simulator")
            }

            let processor = PhotoCaptureProcessor { [weak self] image in
                guard let self, let image else { return }
                self.saveToPhotoLibrary(image)
            }
            self.activeCaptureProcessor = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    // MARK: - Save

    private func saveToPhotoLibrary(_ image: UIImage) {
        #if DEBUG
        if DebugOverrides.forceDeniedPhotos || DebugOverrides.suppressPermissionPrompts {
            print("[Digicam] Debug: suppressing photo library permission prompt/save")
            return
        }
        #endif
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("[Digicam] Photo library access denied: \(status.rawValue)")
                return
            }
            var placeholderID: String?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.creationRequestForAsset(from: image)
                placeholderID = request.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { success, error in
                if let error {
                    print("[Digicam] Save error: \(error)")
                    return
                }
                print("[Digicam] Photo saved to library")
                if let id = placeholderID {
                    var saved = UserDefaults.standard.stringArray(forKey: PhotoLibraryManager.capturedIDsKey) ?? []
                    saved.append(id)
                    UserDefaults.standard.set(saved, forKey: PhotoLibraryManager.capturedIDsKey)
                }
                NotificationCenter.default.post(name: .digicamPhotoSaved, object: nil)
            })
        }
    }
}

// MARK: - CMTime helpers

private func CMTimeClamped(_ time: CMTime, min minTime: CMTime, max maxTime: CMTime) -> CMTime {
    if CMTimeCompare(time, minTime) < 0 { return minTime }
    if CMTimeCompare(time, maxTime) > 0 { return maxTime }
    return time
}
