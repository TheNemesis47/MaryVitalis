import Foundation
import Combine
import WidgetKit

/// Una sessione conclusa e finita nello storico.
struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: String
    let routineId: String
    let routineName: String
    let accentHex: String
    let dayIndex: Int
    let dayName: String
    /// Giorno scelto sul calendario, formato YYYY-MM-DD.
    let date: String
    let duration: Double
    let sets: Int
    let setsDone: Int
    let sips: Int
    let effort: Int?
}

/// Progressi e storico, salvati sul dispositivo come faceva `localStorage`.
final class WorkoutStore: ObservableObject {
    /// [idScheda: [indiceGiorno: [indiceEsercizio: serie completate]]]
    @Published private(set) var progress: [String: [Int: [Int: Int]]] = [:]
    @Published private(set) var history: [HistoryEntry] = []
    @Published var restDefault: Int = WorkoutStore.defaultRest {
        didSet { defaults.set(restDefault, forKey: restKey(for: activeUserID)) }
    }

    static let restOptions = [45, 60, 90, 120]
    static let defaultRest = 90
    static let waterInterval: TimeInterval = 10 * 60
    static let sipsSuggested = 3

    private enum Keys {
        static let progress = "mv:progress"
        static let history = "mv:history"
        static let legacyRest = "mv:rest-default"
        static let restPrefix = "mv:rest-default:"
    }

    private let defaults = UserDefaults.standard
    private var activeUserID = RoutineData.samuel.id

    init() {
        if let data = defaults.data(forKey: Keys.progress),
           let decoded = try? JSONDecoder().decode([String: [String: [String: Int]]].self, from: data) {
            progress = decoded.mapValues { days in
                Dictionary(uniqueKeysWithValues: days.compactMap { key, value -> (Int, [Int: Int])? in
                    guard let dayIndex = Int(key) else { return nil }
                    let exercises = Dictionary(uniqueKeysWithValues: value.compactMap { k, v -> (Int, Int)? in
                        guard let i = Int(k) else { return nil }
                        return (i, v)
                    })
                    return (dayIndex, exercises)
                })
            }
        }
        if let data = defaults.data(forKey: Keys.history),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            history = decoded
        }
        let selected = MaryVitalisShared.selectedUserID
        activeUserID = RoutineData.routine(id: selected) == nil ? RoutineData.samuel.id : selected
        restDefault = storedRest(for: activeUserID)
        publishWidgetSnapshot(selectedUserID: MaryVitalisShared.selectedUserID)
    }

    func activateUser(_ userID: String) {
        guard RoutineData.routine(id: userID) != nil else { return }
        activeUserID = userID
        restDefault = storedRest(for: userID)
        publishWidgetSnapshot(selectedUserID: userID)
    }

    private func storedRest(for userID: String) -> Int {
        let value = defaults.object(forKey: restKey(for: userID)) as? Int
            ?? defaults.object(forKey: Keys.legacyRest) as? Int
            ?? WorkoutStore.defaultRest
        return min(600, max(15, value))
    }

    private func restKey(for userID: String) -> String {
        Keys.restPrefix + userID
    }

    // MARK: - Progressi

    func dayProgress(routineId: String, day: Int) -> [Int: Int] {
        progress[routineId]?[day] ?? [:]
    }

    func doneCount(routineId: String, day: Int, exercise: Int) -> Int {
        dayProgress(routineId: routineId, day: day)[exercise] ?? 0
    }

    /// Le serie restano sempre contigue: si registra "quante ne ho fatte".
    /// Ritorna `true` se il conteggio è aumentato (serve per far partire il recupero).
    @discardableResult
    func setDone(routineId: String, day: Int, exercise: Int, count: Int, maxSets: Int) -> Bool {
        let before = doneCount(routineId: routineId, day: day, exercise: exercise)
        let next = max(0, min(count, maxSets))

        var routine = progress[routineId] ?? [:]
        var dayMap = routine[day] ?? [:]
        dayMap[exercise] = next
        routine[day] = dayMap
        progress[routineId] = routine
        persistProgress()

        return next > before
    }

    func resetDay(routineId: String, day: Int) {
        progress[routineId]?[day] = nil
        persistProgress()
    }

    func stats(routine: Routine, day: Int) -> DayStats {
        DayStats(day: routine.days[day], progress: dayProgress(routineId: routine.id, day: day))
    }

    func completedDays(routine: Routine) -> Int {
        routine.days.indices.filter { stats(routine: routine, day: $0).isComplete }.count
    }

    private func persistProgress() {
        let encodable = progress.mapValues { days in
            Dictionary(uniqueKeysWithValues: days.map { day, exercises in
                (String(day), Dictionary(uniqueKeysWithValues: exercises.map { (String($0.key), $0.value) }))
            })
        }
        if let data = try? JSONEncoder().encode(encodable) {
            defaults.set(data, forKey: Keys.progress)
        }
    }

    // MARK: - Storico

    func addHistory(_ entry: HistoryEntry) {
        history.append(entry)
        persistHistory()
        publishWidgetSnapshot(selectedUserID: MaryVitalisShared.selectedUserID)
    }

    func clearHistory(userID: String) {
        history.removeAll { $0.routineId == userID }
        persistHistory()
        publishWidgetSnapshot(selectedUserID: userID)
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Keys.history)
        }
    }

    /// Pallini colorati per il calendario del profilo: [iso: [colori]].
    func calendarMarks(userID: String) -> [String: [String]] {
        history.filter { $0.routineId == userID }.reduce(into: [String: [String]]()) { acc, entry in
            acc[entry.date, default: []].append(entry.accentHex)
        }
    }

    // MARK: - Widget e comandi dalla Lock Screen

    func publishWidgetSnapshot(selectedUserID: String) {
        guard let user = RoutineData.routine(id: selectedUserID) else { return }
        let lastWorkout = history
            .filter { $0.routineId == selectedUserID }
            .map { DateKey.date(from: $0.date) }
            .max()

        MaryVitalisShared.saveSnapshot(WorkoutWidgetSnapshot(
            userID: user.id,
            userName: user.name,
            accentHex: user.accentHex,
            lastWorkoutDate: lastWorkout,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: MaryVitalisShared.streakWidgetKind)
    }

    /// Applica i tocchi fatti sulla Live Activity mentre l'app era sospesa.
    /// I comandi non appartenenti a questa sessione restano nella coda condivisa.
    @discardableResult
    func consumeWidgetCommands(sessionID: String,
                               routineID: String,
                               dayIndex: Int) -> [WorkoutWidgetCommand] {
        let commands = MaryVitalisShared.consumeCommands(sessionID: sessionID)

        for command in commands
        where command.routineID == routineID && command.dayIndex == dayIndex {
            switch command.kind {
            case .setDone:
                guard let exerciseIndex = command.exerciseIndex,
                      let completedSets = command.completedSets,
                      let routine = RoutineData.routine(id: routineID),
                      routine.days.indices.contains(dayIndex),
                      routine.days[dayIndex].exercises.indices.contains(exerciseIndex) else { continue }
                let plan = routine.days[dayIndex].exercises[exerciseIndex].plan
                setDone(routineId: routineID, day: dayIndex, exercise: exerciseIndex,
                        count: completedSets, maxSets: plan.sets)

            case .restPreference:
                if let seconds = command.restSeconds,
                   WorkoutStore.restOptions.contains(seconds) {
                    restDefault = seconds
                }

            case .restChanged:
                break
            }
        }

        return commands
    }
}
