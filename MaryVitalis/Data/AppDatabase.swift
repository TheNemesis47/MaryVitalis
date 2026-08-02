import Foundation
import SwiftData

/// Il contenitore SwiftData dell'app: il magazzino **locale**, quello che fa
/// funzionare l'app anche senza rete.
///
/// La sincronizzazione non passa più da CloudKit ma da Firebase (vedi
/// `docs/PIANO_MULTIUTENTE.md` §0.3): serviva la condivisione fra utenti
/// diversi — il trainer che scrive la scheda al cliente — che il database
/// privato di CloudKit non sa fare. Perciò qui `cloudKitDatabase` è `.none`:
/// due sincronizzazioni sugli stessi dati litigherebbero.
enum AppDatabase {
    static let schema = Schema([
        UserAccount.self,
        TrainerLink.self,
        Routine.self,
        RoutineDay.self,
        RoutineItem.self,
        WorkoutSession.self,
        DayProgress.self,
        Gym.self,
        GymZone.self,
        GymEquipment.self,
        ExerciseEquipmentLink.self
    ])

    /// `true` quando il contenitore è finito in memoria per un errore di
    /// apertura. Da mostrare all'utente: senza avviso, i dati sembrerebbero
    /// spariti da soli. La schermata che lo usa arriva con la fase 2.
    private(set) static var isEphemeral = false

    /// Percorso esplicito dello store, con la cartella creata a mano.
    /// Su un contenitore appena installato `Application Support` non esiste
    /// ancora e SwiftData non la crea da sé: senza questo, la prima apertura
    /// fallisce e l'app parte senza dati.
    private static func storeURL() -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("MaryVitalis.store")
    }

    static let shared: ModelContainer = {
        let configuration = storeURL().map {
            ModelConfiguration(schema: schema, url: $0, cloudKitDatabase: .none)
        } ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Un fallimento qui è quasi sempre una migrazione di schema
            // incompatibile. Meglio partire su un contenitore effimero e dirlo,
            // che rifiutarsi di avviare.
            isEphemeral = true
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()
}
