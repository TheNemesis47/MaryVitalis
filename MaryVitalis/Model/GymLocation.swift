import SwiftUI

/// Una palestra installata nell'app. Ogni sede possiede aree e attrezzi:
/// aggiungere una nuova sede non richiede modifiche alle viste.
/// Dove sta un attrezzo nella griglia della sala.
struct GymPlacement: Hashable {
    let row: Int
    let column: Int
}

struct GymLocation: Identifiable, Hashable {
    let id: String
    let brand: String
    let name: String
    let city: String
    let address: String?
    let zones: [GymZoneFrame]
    let machines: [GymMachine]
    /// Quanto è larga la sala. Non più quattro corsie fisse: una palestra con
    /// sei attrezzi affiancati va disegnata con sei colonne.
    var columns: Int = 4
    var rows: Int = 0
    /// [id attrezzo: posizione]. Arriva dall'editor, non più dedotta da un
    /// rilievo continuo: la posizione la sceglie chi mappa la sala.
    var placements: [String: GymPlacement] = [:]

    var displayName: String { "\(brand) \(name)" }

    func machine(id: String) -> GymMachine? {
        machines.first { $0.id == id }
    }

    func zone(for machine: GymMachine) -> GymZoneFrame? {
        zones.first { $0.frame.contains(machine.center) }
    }

    var byCategory: [(GymMachine.Category, [GymMachine])] {
        GymMachine.Category.allCases.compactMap { category in
            let matches = machines.filter { $0.category == category }
            return matches.isEmpty ? nil : (category, matches)
        }
    }

    static func == (lhs: GymLocation, rhs: GymLocation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Il posto di nessuno: quello che la mappa mostra a chi non ha ancora
    /// mappato una sala. Prima al suo posto compariva la palestra di Napoli.
    static let none = GymLocation(id: "", brand: "", name: "Nessuna sede",
                                  city: "", address: nil, zones: [], machines: [])
}

struct GymZoneFrame: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let colorHex: String
    let frame: CGRect
    var color: Color { Color(hex: colorHex) }
}

/// Quello che l'app sa delle palestre senza che nessuno gliel'abbia detto.
///
/// Non contiene più nessuna **sede**: la sala di FitActive La Birreria era la
/// palestra di una persona, e comparire come punto di partenza a un utente di
/// Milano non aveva senso. Restano gli attrezzi, che sono conoscenza generale.
enum GymCatalog {
    /// Gli attrezzi che l'app conosce già: è quello che resta del rilievo,
    /// ed è la libreria da cui si pesca costruendo la propria sala.
    static var knownMachines: [GymMachine] { GymMap.machines }

    static func machines(for query: String, in location: GymLocation) -> [GymMachine] {
        let available = Set(location.machines.map(\.id))
        return GymMap.machines(for: query).filter { available.contains($0.id) }
    }

    /// Gli attrezzi **della sede dell'utente** su cui si fa un esercizio.
    ///
    /// Il collegamento passa da `catalogItemID`: la posta in gioco è che
    /// "Dove si fa" indichi una macchina che in quella sala esiste davvero,
    /// invece di una di una palestra di Napoli che l'utente non ha mai visto.
    static func machines(for query: String, in gym: Gym) -> [GymMachine] {
        let wanted = Set(GymMap.machines(for: query).map(\.id))
        guard !wanted.isEmpty else { return [] }

        let matching = Set(gym.orderedEquipment
            .filter { item in item.catalogItemID.map(wanted.contains) ?? false }
            .map(\.id.uuidString))
        guard !matching.isEmpty else { return [] }

        return gym.asLocation.machines.filter { matching.contains($0.id) }
    }
}
