import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

/// Il collegamento con Firebase: identità e magazzino condiviso.
///
/// SwiftData resta la fonte da cui la UI legge — l'app deve funzionare in
/// palestra, dove il telefono spesso non prende. Firestore è quello che rende i
/// dati raggiungibili da un altro dispositivo e dal proprio trainer.
enum FirebaseService {
    private(set) static var isConfigured = false

    /// Va chiamata una sola volta all'avvio, prima di qualunque uso di Auth o
    /// Firestore. Senza il file di configurazione non fa niente e lo dice:
    /// l'app resta utilizzabile in locale invece di rifiutarsi di partire.
    @discardableResult
    static func configure() -> Bool {
        guard !isConfigured else { return true }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return false
        }
        FirebaseApp.configure()

        // La cache su disco è il motivo per cui l'app continua a funzionare
        // senza rete: le scritture partono appena la connessione torna.
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        isConfigured = true
        return true
    }

    static var db: Firestore { Firestore.firestore() }

    static var currentUserID: String? { Auth.auth().currentUser?.uid }
}

/// Nomi delle collezioni, in un posto solo: sono ripetuti nelle regole di
/// sicurezza in `firebase/firestore.rules` e devono restare allineati.
enum FirestorePath {
    static let users = "users"
    static let inviteCodes = "inviteCodes"
    static let trainerLinks = "trainerLinks"
    static let routines = "routines"
    static let days = "days"
    static let sessions = "sessions"
    static let progress = "progress"
    static let gyms = "gyms"
    static let gymCodes = "gymCodes"

    /// Identificativo deterministico del legame, così le regole possono
    /// verificarne l'esistenza senza doverlo cercare.
    static func linkID(trainer: String, client: String) -> String {
        "\(trainer)_\(client)"
    }
}
