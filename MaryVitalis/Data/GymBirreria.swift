import Foundation
import SwiftData

/// Il rilievo di FitActive La Birreria, pronto da importare.
///
/// Non è più la sede di partenza di tutti — quella palestra è di chi ci va, e a
/// un utente di Milano non diceva niente. Ma il lavoro di mapparla esiste, e
/// chi si allena lì deve poterselo prendere: si digita il codice come per una
/// sede condivisa da una persona, e ne arriva una copia propria da adattare.
///
/// Le posizioni non si calcolano più a ogni avvio da coordinate continue: sono
/// state ricavate una volta sola dal rilievo (commit 5ffbf19^, `SpatialGrid`) e
/// scritte qui. Riga e colonna sono un dato, come per qualunque altra sede.
enum GymBirreria {
    /// Il codice da digitare in "Importa con un codice".
    /// Non viene mai generato per una sede vera: `InviteCode.generate()` lo salta.
    static let code = "BRRERA"

    static let brand = "FitActive"
    static let name = "La Birreria"
    static let city = "Napoli"
    static let columns = 4
    static let rows = 21

    struct Cell {
        let row: Int
        let column: Int
    }

    struct Zone {
        let name: String
        let subtitle: String
        let symbol: String
        let colorHex: String
        let startRow: Int
        let endRow: Int
    }

    /// [id dell'attrezzo nel catalogo: posizione in sala] — 53 attrezzi.
    static let placements: [String: Cell] = [
        "pedana-vibrante": Cell(row: 0, column: 2),
        "leg-press": Cell(row: 1, column: 0),
        "area-corpo-libero": Cell(row: 1, column: 1),
        "panca-declinata-1": Cell(row: 1, column: 2),
        "panca-declinata-2": Cell(row: 1, column: 3),
        "hack-squat": Cell(row: 2, column: 1),
        "rear-delt-pec-fly": Cell(row: 2, column: 3),
        "prone-leg-curl": Cell(row: 3, column: 0),
        "glute": Cell(row: 3, column: 1),
        "seated-row": Cell(row: 3, column: 2),
        "matrix-da-identificare": Cell(row: 4, column: 0),
        "leg-curl-extension": Cell(row: 4, column: 1),
        "lateral-raise-1": Cell(row: 4, column: 2),
        "diverging-seated-row": Cell(row: 4, column: 3),
        "cardio-non-identificato": Cell(row: 5, column: 3),
        "hip-adductor-abductor": Cell(row: 6, column: 1),
        "lateral-raise-2": Cell(row: 6, column: 2),
        "converging-chest-press": Cell(row: 6, column: 3),
        "dip-chin-assist": Cell(row: 7, column: 0),
        "decline-press": Cell(row: 7, column: 1),
        "chest-incline-shoulder-press": Cell(row: 7, column: 2),
        "abdominal-crunch": Cell(row: 7, column: 3),
        "stepmill": Cell(row: 8, column: 3),
        "low-row": Cell(row: 9, column: 1),
        "diverging-lat-pulldown": Cell(row: 9, column: 2),
        "tapis-1": Cell(row: 9, column: 3),
        "lat-pulldown-2": Cell(row: 10, column: 0),
        "adjustable-pulley-1": Cell(row: 10, column: 1),
        "colonna-multi-4": Cell(row: 10, column: 2),
        "adjustable-pulley-2": Cell(row: 10, column: 3),
        "cyclette-1": Cell(row: 11, column: 2),
        "tapis-2": Cell(row: 11, column: 3),
        "lat-pulldown": Cell(row: 12, column: 1),
        "cyclette-2": Cell(row: 12, column: 2),
        "tapis-3": Cell(row: 12, column: 3),
        "adjustable-pulley-3": Cell(row: 13, column: 1),
        "cyclette-3": Cell(row: 13, column: 2),
        "tapis-4": Cell(row: 13, column: 3),
        "colonna-multi-2": Cell(row: 14, column: 1),
        "cyclette-4": Cell(row: 14, column: 2),
        "adjustable-pulley-4": Cell(row: 15, column: 1),
        "cyclette-5": Cell(row: 15, column: 2),
        "tapis-5": Cell(row: 15, column: 3),
        "rematore": Cell(row: 16, column: 2),
        "tapis-6": Cell(row: 16, column: 3),
        "manubri": Cell(row: 17, column: 0),
        "panche": Cell(row: 17, column: 1),
        "ellittica-1": Cell(row: 17, column: 2),
        "tapis-7": Cell(row: 17, column: 3),
        "ellittica-2": Cell(row: 18, column: 2),
        "tapis-8": Cell(row: 18, column: 3),
        "tapis-9": Cell(row: 19, column: 3),
        "tapis-10": Cell(row: 20, column: 3),
    ]

    static let zones: [Zone] = [
        Zone(name: "Forza Nord", subtitle: "Gambe e spinte guidate",
             symbol: "figure.strengthtraining.functional", colorHex: "#38bdf8",
             startRow: 1, endRow: 6),
        Zone(name: "Cavi & Functional", subtitle: "Colonne, corpo libero e mobilità",
             symbol: "figure.cooldown", colorHex: "#a78bfa",
             startRow: 0, endRow: 7),
        Zone(name: "Isotonica", subtitle: "Macchine guidate full body",
             symbol: "figure.strengthtraining.traditional", colorHex: "#4ade80",
             startRow: 7, endRow: 15),
        Zone(name: "Cardio", subtitle: "Tapis roulant, bike e scale",
             symbol: "heart.fill", colorHex: "#fb7185",
             startRow: 8, endRow: 20),
        Zone(name: "Pesi liberi", subtitle: "Manubri, panche e spazio a terra",
             symbol: "dumbbell.fill", colorHex: "#fbbf24",
             startRow: 16, endRow: 18),
    ]

    /// Ne scrive una copia nel profilo indicato. Copia, non prestito: da qui in
    /// poi è sua e la modifica come vuole.
    @MainActor
    @discardableResult
    static func insert(for owner: UserAccount, into context: ModelContext) -> Gym {
        let gym = Gym(brand: brand, name: name, city: city,
                      columns: columns, rows: rows,
                      sortIndex: owner.gyms?.count ?? 0)
        gym.owner = owner
        context.insert(gym)

        for machine in GymCatalog.knownMachines {
            guard let cell = placements[machine.id] else { continue }
            let item = GymEquipment(
                catalogItemID: machine.id,
                name: machine.name,
                subtitle: machine.subtitle,
                category: machine.category,
                gridRow: cell.row,
                gridColumn: cell.column,
                muscles: machine.muscles,
                howTo: machine.howTo,
                tips: machine.tips,
                uncertain: machine.uncertain
            )
            item.gym = gym
            context.insert(item)
        }

        for zone in zones {
            let stored = GymZone(name: zone.name, subtitle: zone.subtitle,
                                 symbol: zone.symbol, colorHex: zone.colorHex,
                                 startRow: zone.startRow, endRow: zone.endRow)
            stored.gym = gym
            context.insert(stored)
        }

        return gym
    }
}
