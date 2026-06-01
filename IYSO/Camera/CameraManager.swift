import AVFoundation
import Photos
import UIKit
import os.log

private let cameraLog = OSLog(subsystem: "app.iyso", category: "camera")

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
    private var pendingConfigureDevice: AVCaptureDevice?
    private var sessionRunningObservation: NSKeyValueObservation?
    private static let captureFileNameCountersKey = "digicam.captureFileNameCounters"

    override init() {
        super.init()

        sessionRunningObservation = session.observe(\.isRunning, options: [.new]) { [weak self] _, change in
            guard let self, let isRunning = change.newValue else { return }
            os_log("[Digicam] KVO session.isRunning → %{public}d", log: cameraLog, type: .debug, isRunning ? 1 : 0)
            if isRunning, let device = self.pendingConfigureDevice {
                self.pendingConfigureDevice = nil
                self.sessionQueue.async { self.configureDevice(device) }
            }
            DispatchQueue.main.async { self.isSessionRunning = isRunning }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
    }

    @objc private func handleSessionInterruptionEnded(_ notification: Notification) {
        os_log("[Digicam] Session interruption ended — restarting", log: cameraLog, type: .debug)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    @objc private func handleSessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
        os_log("[Digicam] Session runtime error: %{public}@ — restarting", log: cameraLog, type: .error,
               error?.localizedDescription ?? "unknown")
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.startRunning()
        }
    }

    // MARK: - Session lifecycle

    func startSession() {
        #if DEBUG
        if DebugOverrides.forceDeniedCamera || DebugOverrides.suppressPermissionPrompts {
            return
        }
        #endif
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        os_log("[Digicam] startSession — auth status: %{public}d", log: cameraLog, type: .debug, status.rawValue)
        switch status {
        case .authorized:
            sessionQueue.async { self.configureIfNeededAndStart() }
        case .notDetermined:
            os_log("[Digicam] startSession — camera permission notDetermined", log: cameraLog, type: .debug)
        default:
            os_log("[Digicam] startSession — camera access unavailable (%{public}d)", log: cameraLog, type: .error, status.rawValue)
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Session setup

    private func configureIfNeededAndStart() {
        os_log("[Digicam] configureIfNeededAndStart — isConfigured=%{public}d isRunning=%{public}d",
               log: cameraLog, type: .debug, isConfigured ? 1 : 0, session.isRunning ? 1 : 0)

        if !isConfigured {
            configureSession()
            isConfigured = true
        }

        guard !session.isRunning else {
            os_log("[Digicam] configureIfNeededAndStart — already running, skip", log: cameraLog, type: .debug)
            return
        }

        os_log("[Digicam] calling session.startRunning()", log: cameraLog, type: .debug)
        session.startRunning()
        os_log("[Digicam] session.startRunning() returned — isRunning=%{public}d",
               log: cameraLog, type: .debug, session.isRunning ? 1 : 0)

        // startRunning() is synchronous but can silently fail on first launch in TestFlight
        // when system daemons (e.g. parentalcontrolsd) are simultaneously accessing
        // mediaserverd for first-run setup. Retry once immediately if the session didn't open.
        if !session.isRunning {
            os_log("[Digicam] startRunning() silent failure — retrying", log: cameraLog, type: .error)
            session.startRunning()
            os_log("[Digicam] retry startRunning() — isRunning=%{public}d",
                   log: cameraLog, type: .debug, session.isRunning ? 1 : 0)
        }
    }

    private func configureSession() {
        os_log("[Digicam] configureSession begin", log: cameraLog, type: .debug)
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = discoverUltraWideCamera() else {
            os_log("[Digicam] configureSession — no camera device found", log: cameraLog, type: .error)
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                os_log("[Digicam] configureSession — cannot add input", log: cameraLog, type: .error)
                session.commitConfiguration()
                return
            }
            session.addInput(input)
        } catch {
            os_log("[Digicam] configureSession — input error: %{public}@", log: cameraLog, type: .error,
                   error.localizedDescription)
            session.commitConfiguration()
            return
        }

        photoOutput.maxPhotoQualityPrioritization = .speed

        guard session.canAddOutput(photoOutput) else {
            os_log("[Digicam] configureSession — cannot add output", log: cameraLog, type: .error)
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = false

        session.commitConfiguration()
        os_log("[Digicam] configureSession committed", log: cameraLog, type: .debug)

        // Store device for post-start configuration via KVO handler so setExposureModeCustom
        // doesn't run before the session is confirmed running.
        pendingConfigureDevice = device
    }

    private func discoverUltraWideCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: .back
        )

        if let device = discovery.devices.first {
            os_log("[Digicam] Camera: %{public}@", log: cameraLog, type: .debug, device.localizedName)
            return device
        }

        os_log("[Digicam] Ultra-wide not found, falling back to default", log: cameraLog, type: .debug)
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Manual device configuration

    private func configureDevice(_ device: AVCaptureDevice) {
        os_log("[Digicam] configureDevice begin", log: cameraLog, type: .debug)
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let ultraWideNativeEquivalent: CGFloat = 0.5
            let targetEquivalentZoom: CGFloat = 0.9
            let requestedZoomFactor = targetEquivalentZoom / ultraWideNativeEquivalent
            let clampedZoomFactor = min(
                max(requestedZoomFactor, device.minAvailableVideoZoomFactor),
                device.maxAvailableVideoZoomFactor
            )
            device.videoZoomFactor = clampedZoomFactor

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                device.isSubjectAreaChangeMonitoringEnabled = true
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }

            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

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

                device.setExposureModeCustom(duration: clampedDuration, iso: clampedISO) { _ in
                    os_log("[Digicam] Exposure configured", log: cameraLog, type: .debug)
                }
            }
            os_log("[Digicam] configureDevice done", log: cameraLog, type: .debug)
        } catch {
            os_log("[Digicam] configureDevice error: %{public}@", log: cameraLog, type: .error,
                   error.localizedDescription)
        }
    }

    // MARK: - Photo capture

    func capturePhoto() {
        os_log("[Digicam] capturePhoto — isSessionRunning=%{public}d session.isRunning=%{public}d",
               log: cameraLog, type: .debug, isSessionRunning ? 1 : 0, session.isRunning ? 1 : 0)
        guard isSessionRunning else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = false
            settings.photoQualityPrioritization = .speed

            if let flashMode = self.preferredFlashMode() {
                settings.flashMode = flashMode
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
            return
        }
        #endif
        let captureDate = Date()
        let fileName = nextCaptureFileName(for: captureDate)

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            os_log("[Digicam] Photo library not authorized (%{public}d)", log: cameraLog, type: .error, status.rawValue)
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
                    os_log("[Digicam] Save error: %{public}@", log: cameraLog, type: .error,
                           error.localizedDescription)
                    return
                }
                guard success else {
                    os_log("[Digicam] Save failed: unknown error", log: cameraLog, type: .error)
                    return
                }
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
