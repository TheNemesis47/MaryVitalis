import Foundation
import SwiftData

// MARK: - Vincoli CloudKit
//
// Ogni attributo ha un valore di default o è opzionale, nessuno usa
// `@Attribute(.unique)` e ogni relazione è opzionale con l'inversa dichiarata.
// Non sono preferenze di stile: senza questi requisiti il `ModelContainer`
// con CloudKit non si apre e l'app parte con il database vuoto.
//
// Gli enum sono salvati come `String` grezza perché CloudKit non sa
// rappresentare i tipi Swift: l'enum resta accessibile come computed property.

@Model
final class UserAccount {
    var id: UUID = UUID()
    var displayName: String = ""
    /// Profilo locale: la password vive nel Keychain, mai qui.
    var email: String?
    /// Identità cloud, valorizzata da Sign in with Apple.
    var appleUserID: String?
    /// L'`uid` di Firebase: è questo che lega il profilo locale al suo gemello
    /// su Firestore, e quindi agli altri dispositivi e al proprio trainer.
    /// Vuoto finché il profilo resta solo su questo telefono.
    var firebaseUID: String?
    /// Ultima volta che questo profilo è stato scritto sul cloud, per capire
    /// chi è più recente quando due dispositivi hanno cambiato la stessa cosa.
    var updatedAt: Date = Date.now
    var role: String = UserRole.member.rawValue
    var symbolName: String = "person.crop.circle.fill"
    var accentHex: String = "#38bdf8"
    var mustChangePassword: Bool = false
    var restDefaultSeconds: Int = 90
    var createdAt: Date = Date.now
    /// Il codice che si detta a voce a un trainer perché possa scriverti la
    /// scheda. Non è un segreto forte: da solo non dà accesso a niente, perché
    /// il collegamento va comunque accettato dal cliente.
    var inviteCode: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Routine.owner)
    var routines: [Routine]?

    @Relationship(deleteRule: .cascade, inverse: \Gym.owner)
    var gyms: [Gym]?

    init(id: UUID = UUID(),
         displayName: String = "",
         email: String? = nil,
         appleUserID: String? = nil,
         firebaseUID: String? = nil,
         role: UserRole = .member,
         symbolName: String = "person.crop.circle.fill",
         accentHex: String = "#38bdf8",
         mustChangePassword: Bool = false,
         restDefaultSeconds: Int = 90,
         createdAt: Date = .now,
         inviteCode: String = InviteCode.generate()) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.appleUserID = appleUserID
        self.firebaseUID = firebaseUID
        self.role = role.rawValue
        self.symbolName = symbolName
        self.accentHex = accentHex
        self.mustChangePassword = mustChangePassword
        self.restDefaultSeconds = restDefaultSeconds
        self.createdAt = createdAt
        self.inviteCode = inviteCode
    }

    var userRole: UserRole {
        get { UserRole(rawValue: role) ?? .member }
        set { role = newValue.rawValue }
    }

    var orderedRoutines: [Routine] {
        (routines ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// Sostituisce `AppAccount.assignedUserIDs`: la relazione trainer↔cliente
/// diventa un'entità propria, così può avere stato e, in futuro, un `CKShare`.
@Model
final class TrainerLink {
    var id: UUID = UUID()
    var trainerAccountID: UUID = UUID()
    var clientAccountID: UUID = UUID()
    var status: String = LinkStatus.accepted.rawValue
    var shareRecordName: String?
    var createdAt: Date = Date.now

    init(id: UUID = UUID(),
         trainerAccountID: UUID,
         clientAccountID: UUID,
         status: LinkStatus = .accepted,
         shareRecordName: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.trainerAccountID = trainerAccountID
        self.clientAccountID = clientAccountID
        self.status = status.rawValue
        self.shareRecordName = shareRecordName
        self.createdAt = createdAt
    }

    var linkStatus: LinkStatus {
        get { LinkStatus(rawValue: status) ?? .accepted }
        set { status = newValue.rawValue }
    }
}

enum LinkStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case revoked
}

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "💪"
    var accentHex: String = "#38bdf8"
    var goal: String = ""
    var summary: String = ""
    /// Etichette libere mostrate sotto il titolo: "3 giorni / settimana", "~1h 15m"...
    var meta: [String] = []
    /// Chi ha scritto la scheda: un trainer che la compila per un cliente
    /// resta l'autore anche se il proprietario è il cliente.
    var authorAccountID: UUID?
    /// Una scheda template si applica a più clienti: la copia è per valore,
    /// modificare il template non tocca le schede già assegnate.
    var isTemplate: Bool = false
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var owner: UserAccount?

    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    var days: [RoutineDay]?

    init(id: UUID = UUID(),
         name: String = "",
         emoji: String = "💪",
         accentHex: String = "#38bdf8",
         goal: String = "",
         summary: String = "",
         meta: [String] = [],
         authorAccountID: UUID? = nil,
         isTemplate: Bool = false,
         sortIndex: Int = 0,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.accentHex = accentHex
        self.goal = goal
        self.summary = summary
        self.meta = meta
        self.authorAccountID = authorAccountID
        self.isTemplate = isTemplate
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var orderedDays: [RoutineDay] {
        (days ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var totalExercises: Int {
        orderedDays.reduce(0) { $0 + $1.orderedItems.count }
    }
}

/// Il numero di giorni è libero: non più "giorno 1, 2, 3" ma quanti ne servono.
@Model
final class RoutineDay {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    /// 1 = domenica, come `Calendar`. `nil` quando la scheda non fissa i giorni.
    var preferredWeekday: Int?

    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.day)
    var items: [RoutineItem]?

    init(id: UUID = UUID(),
         name: String = "",
         sortIndex: Int = 0,
         preferredWeekday: Int? = nil) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.preferredWeekday = preferredWeekday
    }

    var orderedItems: [RoutineItem] {
        (items ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// Serie, ripetizioni e minuti sono campi veri. La stringa `details` che la
/// vecchia versione analizzava con due espressioni regolari ora viene generata.
@Model
final class RoutineItem {
    var id: UUID = UUID()
    /// Chiave di ricerca dentro `exercises.json`.
    var exerciseQuery: String = ""
    /// Nome leggibile, tenuto in cache per non dipendere dal caricamento del database.
    var exerciseName: String = ""
    var sets: Int = 1
    /// Libero apposta: "12", "8-10", "max" sono tutti validi.
    var repsText: String?
    /// Valorizzato solo per i blocchi cardio.
    var minutes: Int?
    var note: String?
    var restOverrideSeconds: Int?
    var sortIndex: Int = 0
    /// La riga originale, quando l'esercizio arriva da una scheda scritta a mano
    /// nel vecchio formato testuale. I campi strutturati non sempre riescono a
    /// contenerla tutta — "15-20 min - 5-6 km/h" ha un intervallo e una velocità
    /// che `minutes` da solo perde — e quel testo l'ha scritto una persona.
    /// L'editor lo azzera appena l'esercizio viene modificato davvero.
    var rawDetails: String?

    var day: RoutineDay?

    init(id: UUID = UUID(),
         exerciseQuery: String = "",
         exerciseName: String = "",
         sets: Int = 1,
         repsText: String? = nil,
         minutes: Int? = nil,
         note: String? = nil,
         restOverrideSeconds: Int? = nil,
         sortIndex: Int = 0,
         rawDetails: String? = nil) {
        self.id = id
        self.exerciseQuery = exerciseQuery
        self.exerciseName = exerciseName
        self.sets = sets
        self.repsText = repsText
        self.minutes = minutes
        self.note = note
        self.restOverrideSeconds = restOverrideSeconds
        self.sortIndex = sortIndex
        self.rawDetails = rawDetails
    }

    var isCardio: Bool { minutes != nil }

    /// La riga nel formato che la Live Activity e lo storico mostrano da sempre.
    var details: String {
        if let rawDetails, !rawDetails.isEmpty { return rawDetails }
        if let minutes {
            let suffix = note.map { " - \($0)" } ?? ""
            return "\(minutes) min\(suffix)"
        }
        var text = "\(sets) serie x \(repsText ?? "?") ripetizioni"
        if let note { text += " (\(note))" }
        return text
    }
}

/// Sostituisce `HistoryEntry`. I campi denormalizzati (nome scheda, colore)
/// restano nello storico anche se la scheda viene poi rinominata o cancellata.
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var ownerAccountID: UUID = UUID()
    var routineID: UUID = UUID()
    var routineName: String = ""
    var accentHex: String = "#38bdf8"
    var dayIndex: Int = 0
    var dayName: String = ""
    /// Giorno scelto sul calendario, formato YYYY-MM-DD.
    var dateKey: String = ""
    var duration: Double = 0
    var sets: Int = 0
    var setsDone: Int = 0
    var sips: Int = 0
    var effort: Int?

    init(id: UUID = UUID(),
         ownerAccountID: UUID,
         routineID: UUID,
         routineName: String = "",
         accentHex: String = "#38bdf8",
         dayIndex: Int = 0,
         dayName: String = "",
         dateKey: String = "",
         duration: Double = 0,
         sets: Int = 0,
         setsDone: Int = 0,
         sips: Int = 0,
         effort: Int? = nil) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.routineID = routineID
        self.routineName = routineName
        self.accentHex = accentHex
        self.dayIndex = dayIndex
        self.dayName = dayName
        self.dateKey = dateKey
        self.duration = duration
        self.sets = sets
        self.setsDone = setsDone
        self.sips = sips
        self.effort = effort
    }
}

/// Serie completate di un esercizio, in corso. La chiave è composita:
/// (proprietario, scheda, giorno, esercizio). È qui che si rompe la vecchia
/// conflazione fra identità dell'utente e identità della scheda.
@Model
final class DayProgress {
    var id: UUID = UUID()
    var ownerAccountID: UUID = UUID()
    var routineID: UUID = UUID()
    var dayID: UUID = UUID()
    var itemID: UUID = UUID()
    var completedSets: Int = 0
    var updatedAt: Date = Date.now

    init(id: UUID = UUID(),
         ownerAccountID: UUID,
         routineID: UUID,
         dayID: UUID,
         itemID: UUID,
         completedSets: Int = 0,
         updatedAt: Date = .now) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.routineID = routineID
        self.dayID = dayID
        self.itemID = itemID
        self.completedSets = completedSets
        self.updatedAt = updatedAt
    }
}

@Model
final class Gym {
    var id: UUID = UUID()
    var brand: String = ""
    var name: String = ""
    var city: String = ""
    var address: String?
    /// Larghezza della griglia della sala.
    var columns: Int = 4
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Il codice con cui altri possono importare questa sede. Vuoto finché non
    /// viene condivisa: mappare una palestra è lavoro, e chi lo fa decide se
    /// regalarlo.
    var shareCode: String = ""
    var isShared: Bool = false
    /// Da dove arriva, quando è la copia della sede di qualcun altro.
    var sourceGymID: UUID?

    var owner: UserAccount?

    @Relationship(deleteRule: .cascade, inverse: \GymZone.gym)
    var zones: [GymZone]?

    @Relationship(deleteRule: .cascade, inverse: \GymEquipment.gym)
    var equipment: [GymEquipment]?

    init(id: UUID = UUID(),
         brand: String = "",
         name: String = "",
         city: String = "",
         address: String? = nil,
         columns: Int = 4,
         sortIndex: Int = 0,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         shareCode: String = "",
         isShared: Bool = false,
         sourceGymID: UUID? = nil) {
        self.id = id
        self.brand = brand
        self.name = name
        self.city = city
        self.address = address
        self.columns = columns
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.shareCode = shareCode
        self.isShared = isShared
        self.sourceGymID = sourceGymID
    }

    var displayName: String { "\(brand) \(name)".trimmingCharacters(in: .whitespaces) }

    var orderedEquipment: [GymEquipment] {
        (equipment ?? []).sorted {
            $0.gridRow == $1.gridRow ? $0.gridColumn < $1.gridColumn : $0.gridRow < $1.gridRow
        }
    }

    var rowCount: Int {
        ((equipment ?? []).map(\.gridRow).max() ?? -1) + 1
    }
}

/// Le zone diventano fasce di righe della griglia invece di rettangoli del rilievo.
@Model
final class GymZone {
    var id: UUID = UUID()
    var name: String = ""
    var subtitle: String = ""
    var symbol: String = "square.grid.2x2"
    var colorHex: String = "#38bdf8"
    var startRow: Int = 0
    var endRow: Int = 0

    var gym: Gym?

    init(id: UUID = UUID(),
         name: String = "",
         subtitle: String = "",
         symbol: String = "square.grid.2x2",
         colorHex: String = "#38bdf8",
         startRow: Int = 0,
         endRow: Int = 0) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.symbol = symbol
        self.colorHex = colorHex
        self.startRow = startRow
        self.endRow = endRow
    }

    func contains(row: Int) -> Bool { row >= startRow && row <= endRow }
}

@Model
final class GymEquipment {
    var id: UUID = UUID()
    /// Valorizzato quando l'attrezzo viene dal catalogo di sistema.
    var catalogItemID: String?
    var name: String = ""
    var subtitle: String?
    var category: String = GymMachine.Category.forza.rawValue
    /// Posizione nella griglia della sala: dato primo, non più dedotto dal rilievo.
    var gridRow: Int = 0
    var gridColumn: Int = 0
    var muscles: [String] = []
    var howTo: [String] = []
    var tips: [String] = []
    /// `true` quando nemmeno il rilievo sapeva dire di che attrezzo si tratta.
    var uncertain: Bool = false

    var gym: Gym?

    init(id: UUID = UUID(),
         catalogItemID: String? = nil,
         name: String = "",
         subtitle: String? = nil,
         category: GymMachine.Category = .forza,
         gridRow: Int = 0,
         gridColumn: Int = 0,
         muscles: [String] = [],
         howTo: [String] = [],
         tips: [String] = [],
         uncertain: Bool = false) {
        self.id = id
        self.catalogItemID = catalogItemID
        self.name = name
        self.subtitle = subtitle
        self.category = category.rawValue
        self.gridRow = gridRow
        self.gridColumn = gridColumn
        self.muscles = muscles
        self.howTo = howTo
        self.tips = tips
        self.uncertain = uncertain
    }

    var machineCategory: GymMachine.Category {
        get { GymMachine.Category(rawValue: category) ?? .altro }
        set { category = newValue.rawValue }
    }
}

/// Sostituisce il dizionario cablato `GymMap.queryToMachines`: il collegamento
/// fra un esercizio e l'attrezzo su cui si esegue diventa correggibile.
@Model
final class ExerciseEquipmentLink {
    var id: UUID = UUID()
    var exerciseQuery: String = ""
    var equipmentID: UUID = UUID()
    var gymID: UUID = UUID()
    /// `true` quando il collegamento è stato proposto dall'euristica sul nome
    /// e non ancora confermato dall'utente.
    var isSuggestion: Bool = false

    init(id: UUID = UUID(),
         exerciseQuery: String,
         equipmentID: UUID,
         gymID: UUID,
         isSuggestion: Bool = false) {
        self.id = id
        self.exerciseQuery = exerciseQuery
        self.equipmentID = equipmentID
        self.gymID = gymID
        self.isSuggestion = isSuggestion
    }
}
