import Foundation

enum Fmt {
    static let monthsIT = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
                           "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]
    static let dowIT = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]

    static let effortLabels: [Int: String] = [
        1: "Passeggiata", 2: "Molto leggero", 3: "Leggero", 4: "Discreto", 5: "Impegnativo",
        6: "Bello tosto", 7: "Duro", 8: "Molto duro", 9: "Al limite", 10: "Massimale"
    ]

    /// "7:05" — usato per cronometro e recupero.
    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// "42 min", "1h 15m", "<1 min".
    static func duration(_ seconds: Double) -> String {
        let m = Int((max(0, seconds) / 60).rounded())
        if m < 1 { return "<1 min" }
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
    }

    static func plural(_ n: Int, _ one: String, _ many: String) -> String {
        "\(n) " + (n == 1 ? one : many)
    }

    static func round1(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func capitalizedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
}

// MARK: - Date come stringa locale YYYY-MM-DD (niente sorprese di fuso)

enum DateKey {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // lunedì
        return cal
    }()

    static func iso(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    static func date(from iso: String) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        var c = DateComponents()
        c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c) ?? Date()
    }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? date
    }

    /// La settimana parte da lunedì.
    static func startOfWeek(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date) // 1 = domenica
        let delta = -((weekday + 5) % 7)
        return adding(days: delta, to: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: c) ?? date
    }

    static func addingMonths(_ months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool { iso(a) == iso(b) }

    /// "12 mar"
    static func short(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(c.day ?? 1) " + Fmt.monthsIT[(c.month ?? 1) - 1].prefix(3)
    }

    /// "12 marzo 2026"
    static func long(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        return "\(c.day ?? 1) \(Fmt.monthsIT[(c.month ?? 1) - 1]) \(c.year ?? 0)"
    }

    /// Griglia del mese: settimane da lunedì, incluse le code dei mesi vicini.
    static func monthMatrix(_ month: Date) -> [[Date]] {
        let first = startOfMonth(month)
        let monthIndex = calendar.component(.month, from: first)
        var cursor = startOfWeek(first)
        var weeks: [[Date]] = []

        for _ in 0..<6 {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(cursor)
                cursor = adding(days: 1, to: cursor)
            }
            weeks.append(week)
            if calendar.component(.month, from: cursor) != monthIndex,
               cursor > (calendar.date(byAdding: DateComponents(month: 1, day: -1), to: first) ?? first) {
                break
            }
        }
        return weeks
    }
}
