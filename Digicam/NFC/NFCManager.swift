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
    private var ndefSession: NFCNDEFReaderSession?
    #endif

    var isNFCAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCNDEFReaderSession.readingAvailable
        #endif
    }

    var hasPairedLens: Bool {
        loadFromKeychain(key: pairedTagKey) != nil
    }

    func scanOnLaunch() {
        guard isNFCAvailable else { return }
        startScanning()
    }

    func startScanning() {
        #if targetEnvironment(simulator)
        scanState = .scanning
        #else
        guard NFCNDEFReaderSession.readingAvailable else {
            scanState = .unavailable
            return
        }
        let session = NFCNDEFReaderSession(
            delegate: self,
            queue: .main,
            invalidateAfterFirstRead: true
        )
        session.alertMessage = "Hold your iPhone near the lens clip."
        ndefSession = session
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
        ndefSession?.invalidate()
        ndefSession = nil
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
extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if self.scanState == .scanning { self.scanState = .idle }
            self.ndefSession = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let uid = messages.first?.records.first.map { record in
            record.payload.map { String(format: "%02hhx", $0) }.joined()
        } ?? "NDEF_\(Date().timeIntervalSince1970)"

        DispatchQueue.main.async {
            self.handleTagDetected(uid: uid)
        }
    }
}
#endif
