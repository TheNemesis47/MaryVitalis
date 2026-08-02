import AuthenticationServices
import Foundation
import Security

/// Sign in with Apple: l'identità cloud dell'app.
///
/// È l'identità che regge la sincronizzazione fra i dispositivi della stessa
/// persona, e domani la condivisione trainer↔cliente. Le password dei profili
/// locali (`CredentialStore`) sono un'altra cosa: un lucchetto sul profilo di
/// questo telefono, non un login verso un server.
enum AppleSignIn {
    /// Quello che Apple restituisce all'autorizzazione.
    struct Credential {
        let userID: String
        /// Nome ed email arrivano **solo alla prima autorizzazione**. Se non si
        /// salvano subito, sono persi per sempre: le volte successive Apple
        /// manda solo l'identificativo.
        let fullName: String?
        let email: String?

        /// `true` per gli indirizzi di "Nascondi la mia email".
        var isPrivateRelayEmail: Bool {
            email?.hasSuffix("@privaterelay.appleid.com") ?? false
        }
    }

    enum SignInError: LocalizedError {
        case missingCredential

        var errorDescription: String? {
            switch self {
            case .missingCredential: "Apple non ha restituito un'identità valida."
            }
        }
    }

    static func credential(from authorization: ASAuthorization) throws -> Credential {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw SignInError.missingCredential
        }

        let name = appleCredential.fullName.flatMap { components -> String? in
            let formatted = PersonNameComponentsFormatter.localizedString(from: components,
                                                                          style: .default)
            return formatted.isEmpty ? nil : formatted
        }

        return Credential(userID: appleCredential.user,
                          fullName: name,
                          email: appleCredential.email)
    }

    /// Lo stato dell'autorizzazione, da controllare a ogni avvio: l'utente può
    /// aver revocato l'accesso dalle impostazioni di iOS mentre l'app era chiusa.
    static func isStillAuthorized(userID: String) async -> Bool {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                // `.revoked` e `.notFound` chiudono la sessione. `.transferred`
                // riguarda i passaggi di proprietà dell'app: non è un motivo
                // per buttare fuori nessuno.
                continuation.resume(returning: state == .authorized || state == .transferred)
            }
        }
    }
}

/// Il codice di autorizzazione dell'ultimo accesso con Apple, nel Portachiavi.
///
/// Serve alla revoca, che Apple pretende quando si cancella l'account. Prima
/// stava in una variabile statica: bastava chiudere l'app perché sparisse, e
/// la cancellazione fatta il giorno dopo lasciava il permesso concesso.
enum AppleAuthorizationStore {
    private static let service = "it.maryvitalis.app.apple"
    private static let account = "authorization-code"

    static var code: String? {
        get {
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
        set {
            clear()
            guard let newValue, !newValue.isEmpty else { return }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecValueData: Data(newValue.utf8)
            ]
            SecItemAdd(query as CFDictionary, nil)
        }
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
