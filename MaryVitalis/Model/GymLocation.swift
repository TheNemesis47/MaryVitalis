import SwiftUI

/// Una palestra installata nell'app. Ogni sede possiede aree e attrezzi:
/// aggiungere una nuova sede non richiede modifiche alle viste.
struct GymLocation: Identifiable, Hashable {
    let id: String
    let brand: String
    let name: String
    let city: String
    let address: String?
    let zones: [GymZoneFrame]
    let machines: [GymMachine]

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

enum GymCatalog {
    static let fitActiveLaBirreria = GymLocation(
        id: "fitactive-la-birreria",
        brand: "FitActive",
        name: "La Birreria",
        city: "Napoli",
        address: nil,
        zones: [
            GymZoneFrame(id: "strength-north", name: "Forza Nord", subtitle: "Gambe e spinte guidate",
                    symbol: "figure.strengthtraining.functional", colorHex: "#38bdf8",
                    frame: CGRect(x: 0, y: 0, width: 292, height: 238)),
            GymZoneFrame(id: "functional", name: "Cavi & Functional", subtitle: "Colonne, corpo libero e mobilità",
                    symbol: "figure.cooldown", colorHex: "#a78bfa",
                    frame: CGRect(x: 292, y: 0, width: 199.7, height: 287)),
            GymZoneFrame(id: "guided", name: "Isotonica", subtitle: "Macchine guidate full body",
                    symbol: "figure.strengthtraining.traditional", colorHex: "#4ade80",
                    frame: CGRect(x: 0, y: 238, width: 398, height: 314)),
            GymZoneFrame(id: "cardio", name: "Cardio", subtitle: "Tapis roulant, bike e scale",
                    symbol: "heart.fill", colorHex: "#fb7185",
                    frame: CGRect(x: 398, y: 287, width: 93.7, height: 454)),
            GymZoneFrame(id: "free-weights", name: "Pesi liberi", subtitle: "Manubri, panche e spazio a terra",
                    symbol: "dumbbell.fill", colorHex: "#fbbf24",
                    frame: CGRect(x: 0, y: 552, width: 398, height: 189))
        ],
        machines: GymMap.machines
    )

    static let all: [GymLocation] = [fitActiveLaBirreria]
    static let defaultLocation = fitActiveLaBirreria

    static func location(id: String) -> GymLocation? {
        all.first { $0.id == id }
    }

    static func machines(for query: String, in location: GymLocation = defaultLocation) -> [GymMachine] {
        let available = Set(location.machines.map(\.id))
        return GymMap.machines(for: query).filter { available.contains($0.id) }
    }
}
