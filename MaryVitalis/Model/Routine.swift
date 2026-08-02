import SwiftUI

/// Traduce la riga di testo di una scheda in serie o blocco a tempo.
///
/// Era il cuore del modello: ogni esercizio esisteva solo come stringa
/// (`"4 serie x 12 ripetizioni"`) e queste due espressioni regolari la
/// interpretavano a ogni accesso. Reggeva con dati scritti a mano, non con dati
/// scritti dagli utenti. Ora `RoutineItem` ha `sets`, `repsText` e `minutes`
/// come campi veri, e `Plan` sopravvive solo per leggere il formato storico
/// durante la migrazione.
struct Plan: Hashable {
    let sets: Int
    let minutes: Int?
    /// Le ripetizioni così come erano scritte: "12", "15-20", "45 secondi".
    let repsText: String?
    /// Quello che stava fra parentesi: "(Movimento lento)".
    let note: String?

    init(details: String) {
        let sets = Plan.firstMatch(in: details, pattern: #"(\d+)\s*serie"#)
        let minutes = Plan.firstMatch(in: details, pattern: #"(\d+)(?:\s*[-–]\s*\d+)?\s*min"#)

        if let s = sets, let value = Int(s), value > 0 {
            self.sets = value
            self.minutes = nil
        } else if let m = minutes, let value = Int(m), value > 0 {
            self.sets = 1
            self.minutes = value
        } else {
            self.sets = 1
            self.minutes = nil
        }

        repsText = Plan.firstMatch(in: details, pattern: #"x\s*([\d\-–]+(?:\s*secondi)?)"#)?
            .trimmingCharacters(in: .whitespaces)
        note = Plan.firstMatch(in: details, pattern: #"\(([^)]+)\)"#)
            ?? Plan.firstMatch(in: details, pattern: #"min\s*[-–]\s*(.+)$"#)?
                .trimmingCharacters(in: .whitespaces)
    }

    var isCardio: Bool { minutes != nil }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let group = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[group])
    }
}

extension Routine {
    var accent: Color { Color(hex: accentHex) }
}

extension RoutineItem {
    var accentFallbackName: String {
        exerciseName.isEmpty ? exerciseQuery : exerciseName
    }
}

/// Statistiche di un giorno rispetto ai progressi salvati.
/// I progressi arrivano indicizzati per identificativo dell'esercizio, non più
/// per posizione: riordinare la scheda non sposta più le serie già fatte.
struct DayStats {
    var sets = 0
    var setsDone = 0
    var exercises = 0
    var exercisesDone = 0

    var percent: Int { sets > 0 ? Int((Double(setsDone) / Double(sets) * 100).rounded()) : 0 }
    var isComplete: Bool { sets > 0 && setsDone >= sets }

    init(day: RoutineDay?, progress: [UUID: Int]) {
        guard let day else { return }
        let items = day.orderedItems
        exercises = items.count
        for item in items {
            let done = min(progress[item.id] ?? 0, item.sets)
            sets += item.sets
            setsDone += done
            if done >= item.sets { exercisesDone += 1 }
        }
    }
}
