import SwiftUI

struct RoutineExercise: Identifiable, Hashable {
    let id = UUID()
    /// Nome con cui cercare l'esercizio nel database.
    let query: String
    /// "4 serie x 12 ripetizioni" oppure "10 min - Ritmo leggero".
    let details: String

    var plan: Plan { Plan(details: details) }
}

/// Traduce la riga di testo della scheda in serie o blocco a tempo.
/// Porting di `parsePlan` della SPA.
struct Plan: Hashable {
    let sets: Int
    let minutes: Int?

    init(details: String) {
        let sets = Plan.firstInt(in: details, pattern: #"(\d+)\s*serie"#)
        let minutes = Plan.firstInt(in: details, pattern: #"(\d+)(?:\s*[-–]\s*\d+)?\s*min"#)

        if let s = sets, s > 0 {
            self.sets = s
            self.minutes = nil
        } else if let m = minutes, m > 0 {
            self.sets = 1
            self.minutes = m
        } else {
            self.sets = 1
            self.minutes = nil
        }
    }

    var isCardio: Bool { minutes != nil }

    private static func firstInt(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let group = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[group])
    }
}

struct RoutineDay: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let exercises: [RoutineExercise]
}

struct Routine: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let accentHex: String
    let goal: String
    let summary: String
    let meta: [String]
    let days: [RoutineDay]

    var accent: Color { Color(hex: accentHex) }
    var totalExercises: Int { days.reduce(0) { $0 + $1.exercises.count } }
}

/// Statistiche di un giorno rispetto ai progressi salvati.
struct DayStats {
    var sets = 0
    var setsDone = 0
    var exercises = 0
    var exercisesDone = 0

    var percent: Int { sets > 0 ? Int((Double(setsDone) / Double(sets) * 100).rounded()) : 0 }
    var isComplete: Bool { sets > 0 && setsDone >= sets }

    init(day: RoutineDay, progress: [Int: Int]) {
        exercises = day.exercises.count
        for (index, item) in day.exercises.enumerated() {
            let plan = item.plan
            let done = min(progress[index] ?? 0, plan.sets)
            sets += plan.sets
            setsDone += done
            if done >= plan.sets { exercisesDone += 1 }
        }
    }
}
