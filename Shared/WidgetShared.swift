import ActivityKit
import Foundation

enum MaryVitalisShared {
    static let appGroupIdentifier = "group.it.maryvitalis.shared"
    static let streakWidgetKind = "MaryVitalisWorkoutStreak"

    /// Il formato di quello che passa nell'App Group cambia con questa fase.
    /// L'app lo confronta all'avvio: uno snapshot di versione diversa viene
    /// scartato invece di essere interpretato male.
    static let schemaVersion = 2

    private static let snapshotKey = "mv:widget-snapshot"
    private static let activeAccountKey = "mv:active-account"
    private static let legacySelectedUserKey = "mv:selected-user"
    private static let commandQueueKey = "mv:widget-command-queue"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    /// Il profilo di cui widget e Live Activity mostrano i dati.
    /// Prima era `selectedUserID`, un identificativo di *scheda* usato come se
    /// fosse una persona: è la conflazione che questa fase elimina.
    static var activeAccountID: UUID? {
        get { defaults.string(forKey: activeAccountKey).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: activeAccountKey) }
    }

    /// Il valore scritto dalla versione precedente ("samuel"), letto una volta
    /// sola dalla migrazione.
    static var legacySelectedUserID: String? {
        defaults.string(forKey: legacySelectedUserKey)
    }

    static func loadSnapshot() -> WorkoutWidgetSnapshot {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data),
              snapshot.schemaVersion == schemaVersion else {
            return .placeholder
        }
        return snapshot
    }

    static func saveSnapshot(_ snapshot: WorkoutWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func enqueue(_ command: WorkoutWidgetCommand) {
        var commands = allCommands()
        commands.append(command)
        // Evita che comandi molto vecchi rimangano per sempre se l'app non viene aperta.
        commands = Array(commands.suffix(40))
        saveCommands(commands)
    }

    static func consumeCommands(sessionID: String) -> [WorkoutWidgetCommand] {
        let commands = allCommands()
        let matching = commands.filter { $0.sessionID == sessionID }
        saveCommands(commands.filter { $0.sessionID != sessionID })
        return matching.sorted { $0.createdAt < $1.createdAt }
    }

    private static func allCommands() -> [WorkoutWidgetCommand] {
        guard let data = defaults.data(forKey: commandQueueKey),
              let commands = try? JSONDecoder().decode([WorkoutWidgetCommand].self, from: data) else {
            return []
        }
        return commands
    }

    private static func saveCommands(_ commands: [WorkoutWidgetCommand]) {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: commandQueueKey)
    }
}

/// Quello che il widget "Ultimo allenamento" sa senza poter leggere il database.
/// L'estensione non accede a SwiftData: tutto quello che le serve passa da qui.
struct WorkoutWidgetSnapshot: Codable, Hashable {
    var schemaVersion: Int = MaryVitalisShared.schemaVersion
    var accountID: UUID?
    var userName: String
    var accentHex: String
    var lastWorkoutDate: Date?
    var updatedAt: Date

    /// Neutro apposta: il segnaposto compare anche a chi ha appena installato
    /// l'app e non deve mostrargli il nome di qualcun altro.
    static let placeholder = WorkoutWidgetSnapshot(
        accountID: nil,
        userName: "Nessun profilo",
        accentHex: "#38bdf8",
        lastWorkoutDate: nil,
        updatedAt: Date()
    )

    var hasProfile: Bool { accountID != nil }
}

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ExerciseSummary: Codable, Hashable {
        /// Posizione nella giornata: serve solo a numerare "3 di 7".
        var index: Int
        /// Identità stabile dell'esercizio: è questa che l'app usa per
        /// registrare le serie, così riordinare la scheda non sposta i progressi.
        var itemID: UUID
        var name: String
        var details: String
        var completedSets: Int
        var totalSets: Int
        var isCardio: Bool
    }

    struct ContentState: Codable, Hashable {
        var exercise: ExerciseSummary
        var upcoming: [ExerciseSummary]
        var exerciseNumber: Int
        var totalExercises: Int
        var selectedRestSeconds: Int
        var restEndsAt: Date?
        var pausedRestSeconds: Int?
        var isWorkoutComplete: Bool
        var updatedAt: Date

        var isResting: Bool { restEndsAt != nil || pausedRestSeconds != nil }
    }

    var sessionID: String
    var routineID: UUID
    var dayID: UUID
    var routineName: String
    var userName: String
    var dayIndex: Int
    var accentHex: String
    var startedAt: Date
}

struct WorkoutWidgetCommand: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case setDone
        case restPreference
        case restChanged
    }

    var id = UUID()
    var kind: Kind
    var activityID: String
    var sessionID: String
    var routineID: UUID
    var dayID: UUID
    var dayIndex: Int
    var itemID: UUID?
    var completedSets: Int?
    var restSeconds: Int?
    var restEndsAt: Date?
    var pausedRestSeconds: Int?
    var createdAt = Date()
}
