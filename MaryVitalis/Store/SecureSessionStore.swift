import Foundation
import Security

/// Conserva soltanto l'identificativo dell'account con la sessione attiva.
/// Nessuna password passa di qui: le password dei profili locali stanno in
/// `CredentialStore`, e l'identità cloud è Sign in with Apple.
enum SecureSessionStore {
    private static let service = "it.maryvitalis.app.session"
    private static let account = "active-account"

    static func loadAccountID() -> UUID? {
        rawValue().flatMap(UUID.init(uuidString:))
    }

    /// Il valore scritto dalla versione precedente era un identificativo
    /// testuale ("samuel"), non un UUID. Serve alla migrazione per non
    /// sloggare chi aggiorna.
    static func loadLegacyAccountID() -> String? {
        guard let raw = rawValue(), UUID(uuidString: raw) == nil else { return nil }
        return raw
    }

    @discardableResult
    static func saveAccountID(_ id: UUID) -> Bool {
        clear()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: Data(id.uuidString.utf8)
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

    private static func rawValue() -> String? {
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
}
