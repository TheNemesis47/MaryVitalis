import Foundation
import SwiftData

/// Porta i dati della versione "tre persone cablate nel codice" dentro SwiftData.
///
/// Regole che si è dato:
/// - **idempotente**: gira una volta sola, protetta da un flag;
/// - **non distruttiva**: le chiavi `UserDefaults` vecchie non vengono
///   cancellate, e prima di toccare qualsiasi cosa ne viene salvato un backup
///   JSON su disco;
/// - **atomica**: un solo `save()` finale, così un errore non lascia il
///   database a metà strada.
enum LegacyMigrator {
    private static let migratedKey = "mv:migrated-v2"

    private enum LegacyKeys {
        static let progress = "mv:progress"
        static let history = "mv:history"
        static let rest = "mv:rest-default"
        static let restPrefix = "mv:rest-default:"
    }

    /// Lo storico come lo scriveva `WorkoutStore.HistoryEntry`.
    private struct LegacyHistoryEntry: Codable {
        let id: String
        let routineId: String
        let routineName: String
        let accentHex: String
        let dayIndex: Int
        let dayName: String
        let date: String
        let duration: Double
        let sets: Int
        let setsDone: Int
        let sips: Int
        let effort: Int?
    }

    /// Gli account che esistevano come costanti in `AccountData.all`.
    /// L'account `admin` non viene ricreato: era uno strumento di sviluppo e in
    /// un'app pubblica non ha senso.
    private struct SeedAccount {
        let seedID: String
        let displayName: String
        let role: UserRole
        let symbol: String
        let clients: [String]
    }

    private static let seedAccounts: [SeedAccount] = [
        SeedAccount(seedID: "samuel", displayName: "Samuel", role: .member,
                    symbol: "person.crop.circle.fill", clients: []),
        SeedAccount(seedID: "raffaele", displayName: "Raffaele", role: .member,
                    symbol: "person.crop.circle.fill", clients: []),
        SeedAccount(seedID: "mariapia", displayName: "Maria Pia", role: .trainer,
                    symbol: "figure.strengthtraining.traditional",
                    clients: ["samuel", "raffaele"])
    ]

    /// Password iniziale dei tre profili storici, come richiesto.
    /// Nasce insieme a `mustChangePassword`: al primo accesso l'app propone di
    /// cambiarla, senza obbligare.
    private static let seedPassword = "password"

    // MARK: - Ingresso

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }

        // Se il database ha già degli account, qualcuno ci è arrivato prima:
        // non si duplica nulla, si marca soltanto la migrazione come fatta.
        let existing = (try? context.fetchCount(FetchDescriptor<UserAccount>())) ?? 0
        guard existing == 0 else {
            defaults.set(true, forKey: migratedKey)
            return
        }

        // Su un'installazione pulita non c'è niente da migrare, e i tre profili
        // storici non vanno creati: a chi scarica l'app dall'App Store
        // comparirebbero tre persone sconosciute, sbloccabili con una password
        // nota. Chi arriva qui senza dati vecchi passa dalla registrazione.
        guard hasLegacyData(defaults: defaults) else {
            defaults.set(true, forKey: migratedKey)
            return
        }

        writeBackup(defaults: defaults)

        let seeded = seedAccountsAndRoutines(context: context)
        migrateProgress(context: context, seeded: seeded, defaults: defaults)
        migrateHistory(context: context, seeded: seeded, defaults: defaults)
        migrateRestPreferences(seeded: seeded, defaults: defaults)
        migrateActiveSession(seeded: seeded)

        do {
            try context.save()
            defaults.set(true, forKey: migratedKey)
        } catch {
            // Niente flag: al prossimo avvio si riprova da capo su un
            // contesto pulito, invece di restare con dati a metà.
            context.rollback()
        }
    }

    /// Traccia di un'installazione precedente: progressi, storico, una
    /// preferenza di recupero o una sessione aperta.
    private static func hasLegacyData(defaults: UserDefaults) -> Bool {
        if defaults.data(forKey: LegacyKeys.progress) != nil { return true }
        if defaults.data(forKey: LegacyKeys.history) != nil { return true }
        if defaults.object(forKey: LegacyKeys.rest) != nil { return true }
        if SecureSessionStore.loadLegacyAccountID() != nil { return true }
        if MaryVitalisShared.legacySelectedUserID != nil { return true }
        return defaults.dictionaryRepresentation().keys
            .contains { $0.hasPrefix(LegacyKeys.restPrefix) }
    }

    // MARK: - Backup

    private static func writeBackup(defaults: UserDefaults) {
        var payload: [String: Any] = [:]
        if let data = defaults.data(forKey: LegacyKeys.progress) {
            payload[LegacyKeys.progress] = data.base64EncodedString()
        }
        if let data = defaults.data(forKey: LegacyKeys.history) {
            payload[LegacyKeys.history] = data.base64EncodedString()
        }
        for key in defaults.dictionaryRepresentation().keys
        where key == LegacyKeys.rest || key.hasPrefix(LegacyKeys.restPrefix) {
            payload[key] = defaults.integer(forKey: key)
        }
        guard !payload.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first else { return }

        let url = directory.appendingPathComponent("mv-legacy-backup.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(to: url, options: .atomic)
    }

    // MARK: - Account e schede

    /// Quello che serve per tradurre i vecchi identificativi testuali negli UUID nuovi.
    struct SeedResult {
        /// "samuel" → account
        var accountsBySeedID: [String: UserAccount] = [:]
        /// "samuel" → scheda
        var routinesBySeedID: [String: Routine] = [:]
        /// "samuel" → [indice giorno: giorno]
        var daysBySeedID: [String: [Int: RoutineDay]] = [:]
        /// "samuel" → [indice giorno: [indice esercizio: esercizio]]
        var itemsBySeedID: [String: [Int: [Int: RoutineItem]]] = [:]
    }

    /// Ricrea i tre profili storici con le loro schede. Gira solo su un
    /// dispositivo che ha davvero dati vecchi da recuperare.
    @discardableResult
    private static func seedAccountsAndRoutines(context: ModelContext) -> SeedResult {
        var result = SeedResult()

        for seed in seedAccounts {
            let routineSeed = RoutineData.seed(id: seed.seedID)
            let account = UserAccount(
                displayName: seed.displayName,
                role: seed.role,
                symbolName: seed.symbol,
                accentHex: routineSeed?.accentHex ?? "#38bdf8",
                mustChangePassword: true
            )
            context.insert(account)
            result.accountsBySeedID[seed.seedID] = account
            try? CredentialStore.setPassword(seedPassword, for: account.id)

            guard let routineSeed else { continue }

            // La scheda storica tiene il nome della persona: è così che l'hanno
            // sempre chiamata. Le stesse schede offerte a chi parte da zero
            // prendono invece il nome dell'obiettivo.
            let inserted = RoutineFactory.insert(seed: routineSeed,
                                                 named: routineSeed.name,
                                                 owner: account,
                                                 into: context)

            result.routinesBySeedID[seed.seedID] = inserted.routine
            result.daysBySeedID[seed.seedID] = inserted.days
            result.itemsBySeedID[seed.seedID] = inserted.items
        }

        // `assignedUserIDs: [String]` diventa una relazione con stato proprio.
        for seed in seedAccounts where !seed.clients.isEmpty {
            guard let trainer = result.accountsBySeedID[seed.seedID] else { continue }
            for clientSeedID in seed.clients {
                guard let client = result.accountsBySeedID[clientSeedID] else { continue }
                context.insert(TrainerLink(trainerAccountID: trainer.id,
                                           clientAccountID: client.id,
                                           status: .accepted))
            }
        }

        return result
    }

    // MARK: - Progressi

    private static func migrateProgress(context: ModelContext,
                                        seeded: SeedResult,
                                        defaults: UserDefaults) {
        guard let data = defaults.data(forKey: LegacyKeys.progress),
              let decoded = try? JSONDecoder().decode([String: [String: [String: Int]]].self, from: data) else {
            return
        }

        for (seedID, days) in decoded {
            guard let account = seeded.accountsBySeedID[seedID],
                  let routine = seeded.routinesBySeedID[seedID],
                  let dayMap = seeded.daysBySeedID[seedID],
                  let itemMap = seeded.itemsBySeedID[seedID] else { continue }

            for (dayKey, exercises) in days {
                guard let dayIndex = Int(dayKey), let day = dayMap[dayIndex] else { continue }

                for (exerciseKey, completed) in exercises where completed > 0 {
                    guard let itemIndex = Int(exerciseKey),
                          let item = itemMap[dayIndex]?[itemIndex] else { continue }

                    context.insert(DayProgress(
                        ownerAccountID: account.id,
                        routineID: routine.id,
                        dayID: day.id,
                        itemID: item.id,
                        completedSets: min(completed, item.sets)
                    ))
                }
            }
        }
    }

    // MARK: - Storico

    private static func migrateHistory(context: ModelContext,
                                       seeded: SeedResult,
                                       defaults: UserDefaults) {
        guard let data = defaults.data(forKey: LegacyKeys.history),
              let entries = try? JSONDecoder().decode([LegacyHistoryEntry].self, from: data) else {
            return
        }

        for entry in entries {
            guard let account = seeded.accountsBySeedID[entry.routineId] else { continue }
            let routineID = seeded.routinesBySeedID[entry.routineId]?.id ?? UUID()

            context.insert(WorkoutSession(
                ownerAccountID: account.id,
                routineID: routineID,
                routineName: entry.routineName,
                accentHex: entry.accentHex,
                dayIndex: entry.dayIndex,
                dayName: entry.dayName,
                dateKey: entry.date,
                duration: entry.duration,
                sets: entry.sets,
                setsDone: entry.setsDone,
                sips: entry.sips,
                effort: entry.effort
            ))
        }
    }

    // MARK: - Preferenze e sessione

    private static func migrateRestPreferences(seeded: SeedResult, defaults: UserDefaults) {
        let fallback = defaults.object(forKey: LegacyKeys.rest) as? Int

        for (seedID, account) in seeded.accountsBySeedID {
            let stored = defaults.object(forKey: LegacyKeys.restPrefix + seedID) as? Int ?? fallback
            guard let stored else { continue }
            account.restDefaultSeconds = min(600, max(15, stored))
        }
    }

    /// La vecchia sessione salvava l'identificativo testuale dell'account
    /// ("samuel"). Va tradotto, altrimenti chi aggiorna si ritrova sloggato.
    private static func migrateActiveSession(seeded: SeedResult) {
        let legacySeedID = SecureSessionStore.loadLegacyAccountID()
        let selectedSeedID = MaryVitalisShared.legacySelectedUserID

        if let legacySeedID, let account = seeded.accountsBySeedID[legacySeedID] {
            SecureSessionStore.saveAccountID(account.id)
        }

        if let selectedSeedID, let account = seeded.accountsBySeedID[selectedSeedID] {
            MaryVitalisShared.activeAccountID = account.id
        } else if let first = seeded.accountsBySeedID["samuel"] {
            MaryVitalisShared.activeAccountID = first.id
        }
    }
}
