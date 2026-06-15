import Foundation
import Security

/// Minimal Keychain wrapper for storing sensitive string credentials.
/// Keys are stored as generic passwords scoped to this app's bundle identifier,
/// so no other app can read them without explicit user approval.
enum KeychainStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.dob.app"

    static func set(_ value: String, key: String) {
        let data = Data(value.utf8)
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass:                kSecClassGenericPassword,
            kSecAttrService:          service,
            kSecAttrAccount:          key,
            kSecAttrAccessible:       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData:            data
        ]
        SecItemAdd(query as CFDictionary, nil)
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

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
