import CommonCrypto
import Foundation
import Security

/// Password dei profili locali: più persone che usano lo stesso iPhone.
///
/// Non è una credenziale di rete. CloudKit non fa autenticazione con password —
/// l'identità cloud è Sign in with Apple — quindi questa password è un lucchetto
/// sul profilo, non un login verso un server. Hash e salt vivono nel Keychain,
/// mai nel database e mai su iCloud.
enum CredentialStore {
    private static let service = "it.maryvitalis.app.credentials"
    private static let iterations: UInt32 = 210_000  // raccomandazione OWASP 2023 per PBKDF2-SHA256
    private static let saltLength = 32
    private static let keyLength = 32

    struct StoredCredential: Codable {
        let salt: Data
        let hash: Data
        let iterations: UInt32
    }

    enum CredentialError: Error {
        case randomGenerationFailed
        case derivationFailed
        case keychainWriteFailed(OSStatus)
    }

    // MARK: - API

    static func setPassword(_ password: String, for accountID: UUID) throws {
        var salt = Data(count: saltLength)
        let generated = salt.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, saltLength, base)
        }
        guard generated == errSecSuccess else { throw CredentialError.randomGenerationFailed }

        let hash = try derive(password: password, salt: salt, iterations: iterations)
        let credential = StoredCredential(salt: salt, hash: hash, iterations: iterations)
        try save(credential, for: accountID)
    }

    static func verify(_ password: String, for accountID: UUID) -> Bool {
        guard let credential = load(for: accountID),
              let candidate = try? derive(password: password,
                                          salt: credential.salt,
                                          iterations: credential.iterations) else {
            return false
        }
        return constantTimeEquals(candidate, credential.hash)
    }

    static func hasPassword(for accountID: UUID) -> Bool {
        load(for: accountID) != nil
    }

    static func removeCredentials(for accountID: UUID) {
        SecItemDelete(baseQuery(for: accountID) as CFDictionary)
    }

    // MARK: - Derivazione

    private static func derive(password: String, salt: Data, iterations: UInt32) throws -> Data {
        let passwordBytes = Array(password.utf8)
        var derived = Data(count: keyLength)

        let status: Int32 = derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                guard let derivedBase = derivedBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let saltBase = saltBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return Int32(kCCParamError)
                }
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltBase, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedBase, keyLength
                )
            }
        }

        guard status == kCCSuccess else { throw CredentialError.derivationFailed }
        return derived
    }

    /// Confronto a tempo costante: un `==` su `Data` uscirebbe al primo byte
    /// diverso e renderebbe misurabile quanto prefisso è corretto.
    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }

    // MARK: - Keychain

    private static func baseQuery(for accountID: UUID) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountID.uuidString
        ]
    }

    private static func save(_ credential: StoredCredential, for accountID: UUID) throws {
        removeCredentials(for: accountID)
        guard let data = try? JSONEncoder().encode(credential) else {
            throw CredentialError.derivationFailed
        }
        var query = baseQuery(for: accountID)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecValueData] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw CredentialError.keychainWriteFailed(status) }
    }

    private static func load(for accountID: UUID) -> StoredCredential? {
        var query = baseQuery(for: accountID)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }
}
