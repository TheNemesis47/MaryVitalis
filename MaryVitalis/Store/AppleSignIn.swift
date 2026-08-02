import AuthenticationServices
import Foundation

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
                continuation.resume(returning: state == .authorized)
            }
        }
    }
}
