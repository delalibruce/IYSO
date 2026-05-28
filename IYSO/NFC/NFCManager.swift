import Foundation
import CoreNFC
import Security

enum NFCScanState: Equatable {
    case idle, scanning, detected, wrongTag, unavailable
}

final class NFCManager: NSObject, ObservableObject {
    @Published var scanState: NFCScanState = .idle
    @Published var isLensConnected: Bool = false

    var onLensDetected: (() -> Void)?

    private let pairedTagKey = "com.delali.digicam.nfcPairedUID"

    #if !targetEnvironment(simulator)
    private var tagSession: NFCTagReaderSession?
    #endif

    var isNFCAvailable: Bool {
        guard AppCapabilities.usesNFC else { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCTagReaderSession.readingAvailable
        #endif
    }

    var hasPairedLens: Bool {
        loadFromKeychain(key: pairedTagKey) != nil
    }

    func scanOnLaunch() {
        guard AppCapabilities.usesNFC, isNFCAvailable else { return }
        startScanning()
    }

    func startScanning() {
        guard AppCapabilities.usesNFC else {
            scanState = .unavailable
            return
        }
        #if targetEnvironment(simulator)
        scanState = .scanning
        #else
        guard NFCTagReaderSession.readingAvailable else {
            scanState = .unavailable
            return
        }
        guard let session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        ) else { return }
        session.alertMessage = "Hold your iPhone near the lens clip."
        tagSession = session
        session.begin()
        scanState = .scanning
        #endif
    }

    // Used by simulator/onboarding to simulate a successful NFC detect.
    func simulateDetect() {
        handleTagDetected(uid: "SIMULATOR_LENS_UID")
    }

    func cancelScanning() {
        #if !targetEnvironment(simulator)
        tagSession?.invalidate()
        tagSession = nil
        #endif
        scanState = .idle
    }

    func disconnectLens() {
        isLensConnected = false
        scanState = .idle
    }

    func clearPairedLens() {
        deleteFromKeychain(key: pairedTagKey)
        isLensConnected = false
        scanState = .idle
    }

    private func handleTagDetected(uid: String) {
        if let pairedUID = loadFromKeychain(key: pairedTagKey) {
            if uid == pairedUID {
                scanState = .detected
                isLensConnected = true
                onLensDetected?()
            } else {
                scanState = .wrongTag
            }
        } else {
            saveToKeychain(key: pairedTagKey, value: uid)
            scanState = .detected
            isLensConnected = true
            onLensDetected?()
        }
    }

    // MARK: - Keychain

    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

#if !targetEnvironment(simulator)
extension NFCManager: NFCTagReaderSessionDelegate {
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if self.scanState == .scanning { self.scanState = .idle }
            self.tagSession = nil
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag detected.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }

            if error != nil {
                session.invalidate(errorMessage: "Failed to connect. Try again.")
                DispatchQueue.main.async {
                    self.scanState = .idle
                }
                return
            }

            let uid = self.tagIdentifierHex(for: tag)
            session.alertMessage = "Lens detected."
            session.invalidate()

            DispatchQueue.main.async {
                self.handleTagDetected(uid: uid)
            }
        }
    }

    private func tagIdentifierHex(for tag: NFCTag) -> String {
        let bytes: Data
        switch tag {
        case .miFare(let miFareTag):
            bytes = miFareTag.identifier
        case .iso7816(let iso7816Tag):
            bytes = iso7816Tag.identifier
        case .feliCa(let feliCaTag):
            bytes = feliCaTag.currentIDm
        case .iso15693(let iso15693Tag):
            bytes = iso15693Tag.identifier
        @unknown default:
            bytes = Data("UNKNOWN_TAG".utf8)
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
#endif
