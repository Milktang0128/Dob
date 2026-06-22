import Foundation
import Security

/// Minimal Keychain wrapper for sensitive string credentials. Values are stored
/// as generic passwords scoped to this app's bundle identifier, so no other app
/// can read them without explicit user approval, and they never leave the device
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — no iCloud sync).
///
/// The original wrapper was contributed by @yunbujian (PR #1). It is used here
/// for every credential field, including the per-provider keys that used to live
/// inside the `llmServiceProviders` JSON blob, with UI input routed through it.
enum KeychainStore {
    private static let service = Bundle.main.bundleIdentifier ?? AppFlavor.bundleIdentifier

    /// Stores `value`, replacing any existing entry. An empty value removes the
    /// entry entirely (so a cleared field leaves nothing behind).
    @discardableResult
    static func set(_ value: String, key: String) -> Bool {
        delete(key)
        guard !value.isEmpty else { return true }
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData:      Data(value.utf8)
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
