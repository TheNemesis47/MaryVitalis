import Combine
import Foundation
import SwiftData
import WidgetKit

/// Progressi e storico del profilo consultato.
///
/// Ogni scrittura è legata a un `ownerAccountID` esplicito. Prima i progressi
/// erano indicizzati per identificativo di *scheda*, il che funzionava soltanto
/// finché ogni persona aveva esattamente una scheda con il proprio nome.
@MainActor
final class WorkoutStore: ObservableObject {
    static let restOptions = [45, 60, 90, 120]
    static let defaultRest = 90
    static let waterInterval: TimeInterval = 10 * 60
    static let sipsSuggested = 3

    /// Lo storico del profilo attivo, dal più recente al più vecchio.
    @Published private(set) var history: [WorkoutSession] = []

    @Published var restDefault: Int = WorkoutStore.defaultRest {
        didSet {
            let clamped = min(600, max(15, restDefault))
            if clamped != restDefault {
                restDefault = clamped
                return
            }
            guard let account = activeAccount, account.restDefaultSeconds != clamped else { return }
            account.restDefaultSeconds = clamped
            save()
        }
    }

    private let context: ModelContext
    private(set) var ownerAccountID: UUID?
    /// Collegato dopo l'avvio, come per `ProfileStore`.
    var cloud: CloudSync?

    init(context: ModelContext) {
        self.context = context
        activate(accountID: MaryVitalisShared.activeAccountID)
    }

    private var activeAccount: UserAccount? {
        guard let ownerAccountID else { return nil }
        var descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.id == ownerAccountID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Cambia il profilo di cui si leggono progressi, storico e recupero.
    func activate(accountID: UUID?) {
        ownerAccountID = accountID
        reloadHistory()
        if let account = activeAccount, restDefault != account.restDefaultSeconds {
            restDefault = account.restDefaultSeconds
        }
        publishWidgetSnapshot()
    }

    // MARK: - Progressi

    /// Serie completate della giornata, per identificativo di esercizio.
    func dayProgress(routineID: UUID, dayID: UUID) -> [UUID: Int] {
        guard let ownerAccountID else { return [:] }
        let descriptor = FetchDescriptor<DayProgress>(
            predicate: #Predicate {
                $0.ownerAccountID == ownerAccountID
                    && $0.routineID == routineID
                    && $0.dayID == dayID
            }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return Dictionary(rows.map { ($0.itemID, $0.completedSets) },
                          uniquingKeysWith: { current, _ in current })
    }

    func doneCount(routineID: UUID, dayID: UUID, itemID: UUID) -> Int {
        record(routineID: routineID, dayID: dayID, itemID: itemID)?.completedSets ?? 0
    }

    /// Le serie restano sempre contigue: si registra "quante ne ho fatte".
    /// Ritorna `true` se il conteggio è aumentato, così il chiamante sa se far
    /// partire il recupero.
    @discardableResult
    func setDone(routineID: UUID, dayID: UUID, item: RoutineItem, count: Int) -> Bool {
        guard let ownerAccountID else { return false }
        let next = max(0, min(count, item.sets))

        if let existing = record(routineID: routineID, dayID: dayID, itemID: item.id) {
            let before = existing.completedSets
            existing.completedSets = next
            existing.updatedAt = .now
            save()
            pushDayProgress(routineID: routineID, dayID: dayID)
            return next > before
        }

        context.insert(DayProgress(
            ownerAccountID: ownerAccountID,
            routineID: routineID,
            dayID: dayID,
            itemID: item.id,
            completedSets: next
        ))
        save()
        pushDayProgress(routineID: routineID, dayID: dayID)
        return next > 0
    }

    /// Manda sul cloud la giornata intera: una scrittura, non una per serie.
    private func pushDayProgress(routineID: UUID, dayID: UUID) {
        guard let cloud, let uid = activeAccount?.firebaseUID else { return }
        let completed = dayProgress(routineID: routineID, dayID: dayID)
        Task {
            await cloud.pushDayProgress(ownerUID: uid, routineID: routineID,
                                        dayID: dayID, completed: completed)
        }
    }

    func resetDay(routineID: UUID, dayID: UUID) {
        guard let ownerAccountID else { return }
        let descriptor = FetchDescriptor<DayProgress>(
            predicate: #Predicate {
                $0.ownerAccountID == ownerAccountID
                    && $0.routineID == routineID
                    && $0.dayID == dayID
            }
        )
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
        save()
        pushDayProgress(routineID: routineID, dayID: dayID)
    }

    func stats(routine: Routine, dayIndex: Int) -> DayStats {
        let days = routine.orderedDays
        guard days.indices.contains(dayIndex) else { return DayStats(day: nil, progress: [:]) }
        let day = days[dayIndex]
        return DayStats(day: day, progress: dayProgress(routineID: routine.id, dayID: day.id))
    }

    func completedDays(routine: Routine) -> Int {
        routine.orderedDays.indices.filter { stats(routine: routine, dayIndex: $0).isComplete }.count
    }

    private func record(routineID: UUID, dayID: UUID, itemID: UUID) -> DayProgress? {
        guard let ownerAccountID else { return nil }
        var descriptor = FetchDescriptor<DayProgress>(
            predicate: #Predicate {
                $0.ownerAccountID == ownerAccountID
                    && $0.routineID == routineID
                    && $0.dayID == dayID
                    && $0.itemID == itemID
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Storico

    func addSession(routine: Routine,
                    day: RoutineDay,
                    dayIndex: Int,
                    dateKey: String,
                    duration: Double,
                    stats: DayStats,
                    sips: Int,
                    effort: Int?) {
        guard let ownerAccountID else { return }
        // Si tiene il riferimento a quella appena creata: cercarla per data
        // pescherebbe un altro allenamento fatto lo stesso giorno.
        let session = WorkoutSession(
            ownerAccountID: ownerAccountID,
            routineID: routine.id,
            routineName: routine.name,
            accentHex: routine.accentHex,
            dayIndex: dayIndex,
            dayName: day.name,
            dateKey: dateKey,
            duration: duration,
            sets: stats.sets,
            setsDone: stats.setsDone,
            sips: sips,
            effort: effort
        )
        context.insert(session)
        save()
        reloadHistory()
        publishWidgetSnapshot()

        if let cloud, let uid = activeAccount?.firebaseUID {
            Task { await cloud.pushSession(session, ownerUID: uid) }
        }
    }

    func clearHistory() {
        if let cloud {
            let sessions = history
            Task { await cloud.deleteSessions(sessions) }
        }
        for session in history {
            context.delete(session)
        }
        save()
        reloadHistory()
        publishWidgetSnapshot()
    }

    /// Pallini colorati per il calendario del profilo: [iso: [colori]].
    func calendarMarks() -> [String: [String]] {
        history.reduce(into: [String: [String]]()) { acc, session in
            acc[session.dateKey, default: []].append(session.accentHex)
        }
    }

    private func reloadHistory() {
        guard let ownerAccountID else {
            history = []
            return
        }
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.ownerAccountID == ownerAccountID },
            sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
        )
        history = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Widget e comandi dalla Lock Screen

    func publishWidgetSnapshot() {
        guard let account = activeAccount else {
            MaryVitalisShared.saveSnapshot(.placeholder)
            WidgetCenter.shared.reloadTimelines(ofKind: MaryVitalisShared.streakWidgetKind)
            return
        }

        let lastWorkout = history.map { DateKey.date(from: $0.dateKey) }.max()

        MaryVitalisShared.saveSnapshot(WorkoutWidgetSnapshot(
            accountID: account.id,
            userName: account.displayName,
            accentHex: account.accentHex,
            lastWorkoutDate: lastWorkout,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: MaryVitalisShared.streakWidgetKind)
    }

    /// Applica i tocchi fatti sulla Live Activity mentre l'app era sospesa.
    /// I comandi di altre sessioni restano nella coda condivisa.
    ///
    /// La validazione ora avviene contro i dati reali della scheda: prima
    /// passava da `RoutineData.routine(id:)`, cioè da un enum compilato che con
    /// schede create dagli utenti non esiste più.
    @discardableResult
    func consumeWidgetCommands(sessionID: String,
                               routineID: UUID,
                               dayID: UUID) -> [WorkoutWidgetCommand] {
        let commands = MaryVitalisShared.consumeCommands(sessionID: sessionID)

        for command in commands
        where command.routineID == routineID && command.dayID == dayID {
            switch command.kind {
            case .setDone:
                guard let itemID = command.itemID,
                      let completedSets = command.completedSets,
                      let item = item(id: itemID) else { continue }
                setDone(routineID: routineID, dayID: dayID, item: item, count: completedSets)

            case .restPreference:
                if let seconds = command.restSeconds, WorkoutStore.restOptions.contains(seconds) {
                    restDefault = seconds
                }

            case .restChanged:
                break
            }
        }

        return commands
    }

    private func item(id: UUID) -> RoutineItem? {
        var descriptor = FetchDescriptor<RoutineItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}
