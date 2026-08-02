import Foundation
import SwiftData

/// Le schede storiche delle tre persone che usavano l'app prima che avesse
/// degli account.
///
/// `LegacyMigrator` le aveva date ai profili **locali** nati dalla migrazione.
/// Poi le stesse persone si sono registrate davvero, con un'email, e quei
/// profili cloud sono nati vuoti: le loro schede erano rimaste indietro, su un
/// profilo dello stesso telefono che nessuno apriva più.
///
/// Il ponte è l'email, e vale una volta sola per profilo: chi si registra con
/// uno di questi tre indirizzi ritrova la sua scheda. Per tutti gli altri non
/// succede niente.
enum HistoricRoutines {
    static let seedByEmail: [String: String] = [
        "arenellasamu00@gmail.com": "samuel",
        "mariapiagallo36@gmail.com": "mariapia",
        "raffaeleiommelli21@gmail.com": "raffaele"
    ]

    /// Ritorna la scheda appena creata, o `nil` se non c'era niente da fare —
    /// email diversa, oppure la scheda ce l'ha già.
    @MainActor
    @discardableResult
    static func restore(for account: UserAccount, into context: ModelContext) -> Routine? {
        guard let email = account.email?.lowercased().trimmingCharacters(in: .whitespaces),
              let seedID = seedByEmail[email],
              let seed = RoutineData.seed(id: seedID) else { return nil }

        let name = RoutineFactory.templateName(for: seed)
        // Idempotente: due accessi non devono lasciare due copie della stessa
        // scheda, e chi l'ha già ricevuta e poi cancellata non se la ritrova.
        guard !account.hasSeenHistoricRoutine else { return nil }

        let inserted = RoutineFactory.insert(seed: seed,
                                             named: name,
                                             owner: account,
                                             sortIndex: account.orderedRoutines.count,
                                             into: context)
        account.hasSeenHistoricRoutine = true
        try? context.save()
        return inserted.routine
    }
}
