import AVFoundation
import Photos
import UIKit

class CameraManager: NSObject, ObservableObject {

    // MARK: - Public state

    let session = AVCaptureSession()
    @Published var isSessionRunning = false

    // MARK: - Private

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let filenameQueue = DispatchQueue(label: "camera.filename.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var activeCaptureProcessor: PhotoCaptureProcessor?
    private var isConfigured = false
    private var sessionRunningObservation: NSKeyValueObservation?
    private static let captureFileNameCountersKey = "digicam.captureFileNameCounters"

    override init() {
        super.init()
        // KVO is the only reliable way to track session running state across threads.
        // Reading session.isRunning after startRunning() via DispatchQueue.main.async
        // can miss the state change due to thread timing on first launch.
        sessionRunningObservation = session.observe(\.isRunning, options: [.new]) { [weak self] _, change in
            guard let self, let isRunning = change.newValue else { return }
            DispatchQueue.main.async { self.isSessionRunning = isRunning }
        }
    }

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
            print("[Digicam] Camera permission not yet granted — request during onboarding")
        default:
            print("[Digicam] Camera access not available")
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            // isSessionRunning is updated via KVO on session.isRunning
        }
    }

    // MARK: - Session setup

    private func configureIfNeededAndStart() {
        if !isConfigured {
            configureSession()
            isConfigured = true
        }

        guard !session.isRunning else { return }

        session.startRunning()
        // isSessionRunning is updated via KVO on session.isRunning
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
        photoOutput.isHighResolutionCaptureEnabled = false

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

            // Zoom: 1.0 on ultra-wide ≈ 0.5x equivalent; ~1.8 ≈ 0.9x equivalent
            let ultraWideNativeEquivalent: CGFloat = 0.5
            let targetEquivalentZoom: CGFloat = 0.9
            let requestedZoomFactor = targetEquivalentZoom / ultraWideNativeEquivalent
            let clampedZoomFactor = min(
                max(requestedZoomFactor, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.videoZoomFactor = clampedZoomFactor

            // Focus: keep autofocus active so close/far subjects stay sharp.
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
                print("[Digicam] Focus configured: continuous auto-focus")
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
                print("[Digicam] Focus configured: single auto-focus")
            } else {
                print("[Digicam] Auto-focus not supported on this device")
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
            settings.isHighResolutionPhotoEnabled = false
            settings.photoQualityPrioritization = .speed

            if let flashMode = self.preferredFlashMode() {
                settings.flashMode = flashMode
            } else {
                print("[Digicam] Flash not supported on this device/simulator")
            }

            let processor = PhotoCaptureProcessor { [weak self] data in
                guard let self, let photoData = data else { return }
                self.saveToPhotoLibrary(photoData)
            }
            self.activeCaptureProcessor = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    // MARK: - Save

    private func saveToPhotoLibrary(_ photoData: Data) {
        #if DEBUG
        if DebugOverrides.forceDeniedPhotos || DebugOverrides.suppressPermissionPrompts {
            print("[Digicam] Debug: suppressing photo library permission prompt/save")
            return
        }
        #endif
        let captureDate = Date()
        let fileName = nextCaptureFileName(for: captureDate)

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            print("[Digicam] Photo library access not granted (status: \(status.rawValue)); enable Photos on Set up capture.")
            return
        }

        var placeholderID: String?
        PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = captureDate

                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileName
                request.addResource(with: .photo, data: photoData, options: options)
                placeholderID = request.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { success, error in
                if let error {
                    print("[Digicam] Save error: \(error)")
                    return
                }
                if !success {
                    print("[Digicam] Save failed: unknown Photos error")
                    return
                }
                print("[Digicam] Photo saved to library as \(fileName)")
                DispatchQueue.main.async {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                if let id = placeholderID {
                    var saved = UserDefaults.standard.stringArray(forKey: PhotoLibraryManager.capturedIDsKey) ?? []
                    saved.append(id)
                    UserDefaults.standard.set(saved, forKey: PhotoLibraryManager.capturedIDsKey)
                }
                NotificationCenter.default.post(name: .digicamPhotoSaved, object: nil)
            })
    }

    private func nextCaptureFileName(for date: Date) -> String {
        filenameQueue.sync {
            let base = "IYSO_\(Self.hourMinuteFormatter.string(from: date))"
            var counters = UserDefaults.standard.dictionary(forKey: Self.captureFileNameCountersKey) as? [String: Int] ?? [:]
            let next = (counters[base] ?? 0) + 1
            counters[base] = next
            UserDefaults.standard.set(counters, forKey: Self.captureFileNameCountersKey)

            if next == 1 {
                return "\(base).JPG"
            }
            return "\(base)\(next - 1).JPG"
        }
    }

    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HHmm"
        return formatter
    }()

    private func preferredFlashMode() -> AVCaptureDevice.FlashMode? {
        if photoOutput.supportedFlashModes.contains(.on) {
            return .on
        }
        return nil
    }
}

// MARK: - CMTime helpers

private func CMTimeClamped(_ time: CMTime, min minTime: CMTime, max maxTime: CMTime) -> CMTime {
    if CMTimeCompare(time, minTime) < 0 { return minTime }
    if CMTimeCompare(time, maxTime) > 0 { return maxTime }
    return time
}
