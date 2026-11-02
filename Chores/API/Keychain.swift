import Foundation
import Security

enum Keychain {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "net.forstberg.chores",
        kSecAttrAccount as String: "refreshToken",
    ]

    static var refreshToken: String? {
        get {
            var query = base
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(base as CFDictionary)
            guard let newValue else { return }
            var item = base
            item[kSecValueData as String] = Data(newValue.utf8)
            // Readable in the background after the first unlock, so a refresh never waits on Face ID.
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
