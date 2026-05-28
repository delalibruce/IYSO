import Foundation
import CoreNFC

enum NFCScanPurpose {
    case register
    case validate
}

final class NFCLensManager: NSObject, ObservableObject {
    static let shared = NFCLensManager()

    var onSuccess: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private let registeredTagKey = "registeredNFCTagID"
    private var currentPurpose: NFCScanPurpose = .register

    #if !targetEnvironment(simulator)
    private var ndefSession: NFCNDEFReaderSession?
    #endif

    private override init() { super.init() }

    func startScan(purpose: NFCScanPurpose) {
        currentPurpose = purpose
        guard AppCapabilities.usesNFC else {
            // In debug / simulator, treat as immediate success for UI testing.
            DispatchQueue.main.async { self.onSuccess?() }
            return
        }
        #if !targetEnvironment(simulator)
        let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = purpose == .register
            ? "Hold your iPhone near the lens clip to register it."
            : "Hold your iPhone near the lens clip to enter IYSO Mode."
        ndefSession = session
        session.begin()
        #endif
    }
}

#if !targetEnvironment(simulator)
extension NFCLensManager: NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError,
           nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            return
        }
        DispatchQueue.main.async {
            self.onFailure?("NFC session ended: \(error.localizedDescription)")
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let payload = messages.first?.records.first?.payload ?? Data()
        let hex = payload.map { String(format: "%02x", $0) }.joined()

        DispatchQueue.main.async {
            switch self.currentPurpose {
            case .register:
                UserDefaults.standard.set(hex, forKey: self.registeredTagKey)
                self.onSuccess?()
            case .validate:
                let saved = UserDefaults.standard.string(forKey: self.registeredTagKey)
                if hex == saved {
                    self.onSuccess?()
                } else {
                    self.onFailure?("This lens clip doesn't match the registered one.")
                }
            }
        }
    }
}
#endif
