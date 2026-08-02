import Foundation
import SwiftData

/// Creazione e modifica delle schede.
///
/// La scheda appartiene sempre al **profilo consultato**, non a chi la scrive:
/// è così che un trainer costruisce la scheda di un cliente e il cliente se la
/// ritrova sul proprio telefono. Chi l'ha scritta resta in `authorAccountID`.
extension ProfileStore {
    // MARK: - Schede

    @discardableResult
    func createRoutine(named name: String = "Nuova scheda",
                       for owner: UserAccount,
                       dayCount: Int = 3) -> Routine {
        let routine = RoutineFactory.insertEmpty(named: name,
                                                 owner: owner,
                                                 dayCount: dayCount,
                                                 into: context)
        routine.authorAccountID = signedInAccountID
        save(routine)
        return routine
    }

    @discardableResult
    func duplicate(_ routine: Routine, for owner: UserAccount? = nil) -> Routine {
        let target = owner ?? routine.owner
        let copy = Routine(
            name: "\(routine.name) (copia)",
            emoji: routine.emoji,
            accentHex: routine.accentHex,
            goal: routine.goal,
            summary: routine.summary,
            meta: routine.meta,
            authorAccountID: signedInAccountID,
            sortIndex: (target?.orderedRoutines.count ?? 0)
        )
        copy.owner = target
        context.insert(copy)

        // Copia per valore: modificare l'originale non tocca la copia. È quello
        // che serve a un trainer che parte da un template e poi lo adatta.
        for day in routine.orderedDays {
            let newDay = RoutineDay(name: day.name,
                                    sortIndex: day.sortIndex,
                                    preferredWeekday: day.preferredWeekday)
            newDay.routine = copy
            context.insert(newDay)

            for item in day.orderedItems {
                let newItem = RoutineItem(
                    exerciseQuery: item.exerciseQuery,
                    exerciseName: item.exerciseName,
                    sets: item.sets,
                    repsText: item.repsText,
                    minutes: item.minutes,
                    note: item.note,
                    restOverrideSeconds: item.restOverrideSeconds,
                    sortIndex: item.sortIndex,
                    rawDetails: item.rawDetails
                )
                newItem.day = newDay
                context.insert(newItem)
            }
        }

        save(copy)
        return copy
    }

    func delete(_ routine: Routine) {
        let id = routine.id
        context.delete(routine)
        try? context.save()
        objectWillChange.send()
        if let cloud {
            Task { await cloud.deleteRoutine(id: id) }
        }
    }

    func moveRoutines(for owner: UserAccount, from offsets: IndexSet, to destination: Int) {
        var routines = owner.orderedRoutines
        routines.move(fromOffsets: offsets, toOffset: destination)
        for (index, routine) in routines.enumerated() {
            routine.sortIndex = index
        }
        try? context.save()
        objectWillChange.send()
        pushAll(routines)
    }

    // MARK: - Giorni

    @discardableResult
    func addDay(to routine: Routine, named name: String? = nil) -> RoutineDay {
        let index = routine.orderedDays.count
        let day = RoutineDay(name: name ?? "Giorno \(index + 1)", sortIndex: index)
        day.routine = routine
        context.insert(day)
        save(routine)
        return day
    }

    func delete(_ day: RoutineDay) {
        let routine = day.routine
        // Stacca la relazione **prima** di cancellare: finché non si salva,
        // l'oggetto cancellato resta nella collezione del genitore, e
        // rinumerare in quel momento lascerebbe buchi negli indici.
        day.routine = nil
        context.delete(day)
        try? context.save()

        if let routine {
            reindexDays(routine)
            save(routine)
        }
    }

    func moveDays(in routine: Routine, from offsets: IndexSet, to destination: Int) {
        var days = routine.orderedDays
        days.move(fromOffsets: offsets, toOffset: destination)
        for (index, day) in days.enumerated() {
            day.sortIndex = index
        }
        save(routine)
    }

    private func reindexDays(_ routine: Routine) {
        for (index, day) in routine.orderedDays.enumerated() {
            day.sortIndex = index
        }
    }

    // MARK: - Esercizi

    @discardableResult
    func addItem(to day: RoutineDay,
                 query: String,
                 name: String,
                 sets: Int = 3,
                 reps: String? = "12",
                 minutes: Int? = nil) -> RoutineItem {
        let item = RoutineItem(
            exerciseQuery: query,
            exerciseName: name,
            sets: sets,
            repsText: reps,
            minutes: minutes,
            sortIndex: day.orderedItems.count
        )
        item.day = day
        context.insert(item)
        if let routine = day.routine { save(routine) }
        return item
    }

    func delete(_ item: RoutineItem) {
        let day = item.day
        item.day = nil
        context.delete(item)
        try? context.save()

        if let day {
            for (index, remaining) in day.orderedItems.enumerated() {
                remaining.sortIndex = index
            }
            if let routine = day.routine { save(routine) }
        }
    }

    func moveItems(in day: RoutineDay, from offsets: IndexSet, to destination: Int) {
        var items = day.orderedItems
        items.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortIndex = index
        }
        if let routine = day.routine { save(routine) }
    }

    // MARK: - Salvataggio

    /// Ogni modifica passa da qui: aggiorna il timestamp — è quello che decide
    /// chi vince quando due dispositivi hanno cambiato la stessa scheda — e
    /// manda la scheda sul cloud, così arriva a chi la sta aspettando.
    func save(_ routine: Routine) {
        routine.updatedAt = .now
        // Un esercizio toccato dall'editor non è più la riga di testo di
        // partenza: da qui in poi comandano i campi strutturati.
        try? context.save()
        objectWillChange.send()
        if let cloud {
            Task { await cloud.pushRoutine(routine) }
        }
    }

    private func pushAll(_ routines: [Routine]) {
        guard let cloud else { return }
        Task {
            for routine in routines {
                await cloud.pushRoutine(routine)
            }
        }
    }
}
