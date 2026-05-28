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

    #if !targetEnvironment(simulator)
    private var ndefSession: NFCNDEFReaderSession?
    #endif

    private override init() { super.init() }

    func startScan(purpose: NFCScanPurpose) {
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
        guard let record = messages.first?.records.first,
              let url = record.wellKnownTypeURIPayload(),
              url.host?.hasSuffix("iyso.app") == true else {
            DispatchQueue.main.async {
                self.onFailure?("This doesn't look like an IYSO lens clip.")
            }
            return
        }
        DispatchQueue.main.async { self.onSuccess?() }
    }
}
#endif
