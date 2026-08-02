import Foundation
import Security

/// Conserva soltanto l'identificativo della sessione locale. Nessuna password
/// viene salvata nell'app: quando arriverà un backend, qui andrà il token opaco.
enum SecureSessionStore {
    private static let service = "it.maryvitalis.app.session"
    private static let account = "active-account"

    static func loadAccountID() -> String? {
        var result: CFTypeRef?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveAccountID(_ id: String) -> Bool {
        clear()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: Data(id.utf8)
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
