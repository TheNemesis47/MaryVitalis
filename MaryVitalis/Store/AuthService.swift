import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

/// Autenticazione vera, quella che funziona da qualsiasi dispositivo.
///
/// Le password non passano più da `CredentialStore`: quelle restano solo per i
/// profili storici e per lo sblocco locale. Qui la password la verifica
/// Firebase, che è l'unico modo per fare login su un telefono che non ha mai
/// visto quell'account.
enum AuthService {
    struct CloudUser {
        let uid: String
        let email: String?
        let displayName: String?
    }

    enum AuthError: LocalizedError {
        case notConfigured
        case appleTokenMissing

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "Il collegamento al cloud non è configurato su questa installazione."
            case .appleTokenMissing:
                "Apple non ha restituito un token valido."
            }
        }
    }

    static var currentUser: CloudUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        return CloudUser(uid: user.uid, email: user.email, displayName: user.displayName)
    }

    // MARK: - Email e password

    static func signUp(email: String, password: String, displayName: String) async throws -> CloudUser {
        try requireConfigured()
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try? await change.commitChanges()
        return CloudUser(uid: result.user.uid, email: result.user.email, displayName: displayName)
    }

    static func signIn(email: String, password: String) async throws -> CloudUser {
        try requireConfigured()
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return CloudUser(uid: result.user.uid,
                         email: result.user.email,
                         displayName: result.user.displayName)
    }

    static func sendPasswordReset(email: String) async throws {
        try requireConfigured()
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Apple

    /// Il `nonce` serve a impedire che qualcuno riusi un token Apple
    /// intercettato: Apple lo firma dentro il token, Firebase verifica che
    /// corrisponda a quello che abbiamo generato per *questa* richiesta.
    private(set) nonisolated(unsafe) static var currentNonce: String?

    static func makeAppleNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Il codice di autorizzazione dell'ultimo accesso con Apple.
    ///
    /// Serve a **revocare** il permesso quando l'utente cancella l'account:
    /// Apple lo pretende, e senza revoca il prossimo "Accedi con Apple"
    /// verrebbe trattato come un ritorno invece che come una registrazione —
    /// niente nome, niente email, e un profilo senza identità. Sta nel
    /// Portachiavi perché deve valere anche fra un avvio e l'altro.
    static var lastAuthorizationCode: String? { AppleAuthorizationStore.code }

    static func signIn(with authorization: ASAuthorization) async throws -> CloudUser {
        try requireConfigured()
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let token = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.appleTokenMissing
        }

        AppleAuthorizationStore.code = appleCredential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }

        let credential = OAuthProvider.appleCredential(withIDToken: token,
                                                       rawNonce: nonce,
                                                       fullName: appleCredential.fullName)
        let result = try await Auth.auth().signIn(with: credential)
        currentNonce = nil

        let name = appleCredential.fullName.flatMap {
            let formatted = PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            return formatted.isEmpty ? nil : formatted
        }

        return CloudUser(uid: result.user.uid,
                         email: result.user.email,
                         displayName: name ?? result.user.displayName)
    }

    // MARK: - Uscita

    static func signOut() {
        try? Auth.auth().signOut()
    }

    static func deleteCloudUser() async throws {
        try await Auth.auth().currentUser?.delete()
    }

    /// Revoca il permesso concesso ad Apple. Va fatta **prima** di cancellare
    /// l'utente, perché richiede una sessione valida.
    static func revokeAppleAccess() async {
        guard let code = lastAuthorizationCode else { return }
        try? await Auth.auth().revokeToken(withAuthorizationCode: code)
        AppleAuthorizationStore.clear()
    }

    // MARK: - Nonce

    private static func requireConfigured() throws {
        guard FirebaseService.isConfigured else { throw AuthError.notConfigured }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
