import Foundation
import Security

/// Zählt die durchgeführten Swaps für das Freemium-Modell.
///
/// Der Zähler liegt im Keychain, nicht in den UserDefaults: Keychain-Einträge
/// überleben das Löschen der App. Sonst wäre der Gratis-Swap durch
/// Deinstallieren und Neuinstallieren beliebig oft zu haben.
enum SwapAllowance {

    /// So viele Swaps sind ohne Kauf möglich.
    static let freeLimit = 1

    private static let service = "com.contactswap.allowance"
    private static let account = "swap-count-v1"

    static var usedSwaps: Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              let count = Int(text) else { return 0 }
        return count
    }

    static var remainingFreeSwaps: Int {
        max(0, freeLimit - usedSwaps)
    }

    static func recordSwap() {
        store(usedSwaps + 1)
    }

    // MARK: - Keychain

    private static func store(_ count: Int) {
        let data = Data(String(count).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let update: [String: Any] = [kSecValueData as String: data]

        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            // AfterFirstUnlock, damit der Zähler auch dann steht, wenn das
            // Gerät seit dem Start noch nicht entsperrt wurde.
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(insert as CFDictionary, nil)
        }
    }
}
