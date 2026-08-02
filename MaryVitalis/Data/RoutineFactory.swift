import Foundation
import SwiftData

/// Costruisce schede vere a partire dalle schede di partenza scritte nel codice.
///
/// Serve a due chiamanti diversi: la migrazione dei dati storici e l'onboarding
/// di chi installa l'app da zero. È lo stesso lavoro, quindi sta in un posto solo.
enum RoutineFactory {
    /// Le schede offerte a chi parte da zero.
    ///
    /// Portano il nome dell'**obiettivo**, non della persona: "Recupero lombare"
    /// dice qualcosa a chiunque, "Samuel" no.
    static var starterTemplates: [SeedRoutine] { RoutineData.all }

    static func templateName(for seed: SeedRoutine) -> String {
        seed.goal.isEmpty ? seed.name : seed.goal
    }

    /// Inserisce nel contesto la scheda, i suoi giorni e i suoi esercizi.
    /// Ritorna la scheda insieme alle mappe indice→oggetto, che servono alla
    /// migrazione per ritrovare i progressi salvati per posizione.
    @discardableResult
    static func insert(seed: SeedRoutine,
                       named name: String,
                       owner: UserAccount,
                       sortIndex: Int = 0,
                       into context: ModelContext) -> InsertedRoutine {
        let routine = Routine(
            name: name,
            emoji: seed.emoji,
            accentHex: seed.accentHex,
            goal: seed.goal,
            summary: seed.summary,
            meta: seed.meta,
            sortIndex: sortIndex
        )
        routine.owner = owner
        context.insert(routine)

        var days: [Int: RoutineDay] = [:]
        var items: [Int: [Int: RoutineItem]] = [:]

        for (dayIndex, daySeed) in seed.days.enumerated() {
            let day = RoutineDay(name: daySeed.name, sortIndex: dayIndex)
            day.routine = routine
            context.insert(day)
            days[dayIndex] = day

            var dayItems: [Int: RoutineItem] = [:]
            for (itemIndex, exerciseSeed) in daySeed.exercises.enumerated() {
                // Unica lettura del vecchio formato testuale: da qui in poi
                // serie, ripetizioni e minuti sono campi veri.
                let plan = Plan(details: exerciseSeed.details)
                let item = RoutineItem(
                    exerciseQuery: exerciseSeed.query,
                    exerciseName: exerciseSeed.query,
                    sets: plan.sets,
                    repsText: plan.repsText,
                    minutes: plan.minutes,
                    note: plan.note,
                    sortIndex: itemIndex,
                    rawDetails: exerciseSeed.details
                )
                item.day = day
                context.insert(item)
                dayItems[itemIndex] = item
            }
            items[dayIndex] = dayItems
        }

        return InsertedRoutine(routine: routine, days: days, items: items)
    }

    /// Una scheda vuota, per chi la vuole costruire da sé.
    @discardableResult
    static func insertEmpty(named name: String,
                            owner: UserAccount,
                            dayCount: Int = 3,
                            into context: ModelContext) -> Routine {
        let routine = Routine(
            name: name,
            emoji: "💪",
            accentHex: owner.accentHex,
            goal: "",
            summary: "",
            meta: ["\(dayCount) giorni / settimana"],
            sortIndex: owner.orderedRoutines.count
        )
        routine.owner = owner
        context.insert(routine)

        for index in 0..<max(1, dayCount) {
            let day = RoutineDay(name: "Giorno \(index + 1)", sortIndex: index)
            day.routine = routine
            context.insert(day)
        }
        return routine
    }

    struct InsertedRoutine {
        let routine: Routine
        /// [indice giorno: giorno]
        let days: [Int: RoutineDay]
        /// [indice giorno: [indice esercizio: esercizio]]
        let items: [Int: [Int: RoutineItem]]
    }
}
