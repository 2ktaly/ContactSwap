import Foundation
import CryptoKit
import Security

/// Verschlüsselt die Backups auf der Platte – ohne dass der Nutzer etwas eingibt.
///
/// Der Schlüssel liegt im Keychain und ist an dieses Gerät gebunden
/// (`ThisDeviceOnly`), lesbar nur bei entsperrtem iPhone. Damit schützt der
/// Gerätecode die Backups implizit, und der Schlüssel wandert in kein
/// iCloud- oder Finder-Backup: Eine kopierte Backup-Datei ist auf einem
/// anderen Gerät wertlos.
enum BackupCrypto {

    enum Failure: LocalizedError {
        case keychain(OSStatus)
        case unreadableKey
        case unreadableData

        var errorDescription: String? {
            switch self {
            case .keychain(let status):
                return "Der Schlüsselbund ließ sich nicht öffnen (Fehler \(status))."
            case .unreadableKey:
                return "Der Schlüssel im Schlüsselbund ist beschädigt."
            case .unreadableData:
                return "Die Backup-Datei ließ sich nicht entschlüsseln."
            }
        }
    }

    private static let service = "com.contactswap.backup"
    private static let account = "backup-key-v1"

    // MARK: - Verschlüsseln

    static func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(data, using: key)
        guard let combined = box.combined else { throw Failure.unreadableData }
        return combined
    }

    static func open(_ data: Data, with key: SymmetricKey) throws -> Data {
        do {
            return try AES.GCM.open(try AES.GCM.SealedBox(combined: data), using: key)
        } catch {
            throw Failure.unreadableData
        }
    }

    // MARK: - Schlüssel

    /// Holt den Schlüssel aus dem Keychain und legt ihn beim ersten Aufruf an.
    ///
    /// Der Aufrufer holt ihn einmal pro Backup-Vorgang und reicht ihn durch –
    /// pro Foto einen Keychain-Zugriff zu machen wäre spürbar langsam.
    static func loadKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, data.count == 32 else { throw Failure.unreadableKey }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return try createKey()
        default:
            throw Failure.keychain(status)
        }
    }

    private static func createKey() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        return key
    }
}
