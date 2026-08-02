import Foundation
import SwiftData
import SwiftUI

/// Crea e traduce le palestre.
///
/// Il rilievo originale di FitActive vive ancora come costanti in
/// `GymMapData.swift`: da lì nasce il **catalogo** da cui chiunque pesca per
/// costruire la propria sala. Nel modello nuovo riga e colonna sono dati
/// primi, non più dedotti dalle coordinate.
enum GymFactory {
    /// Gli attrezzi che l'app conosce già, con testi e istruzioni scritti.
    static var catalog: [GymMachine] { GymMap.machines }

    /// Costruisce una palestra dal rilievo esistente, calcolando riga e colonna
    /// una volta sola con la stessa logica che disegna la mappa.
    @discardableResult
    static func insertFromCatalog(named name: String = "La Birreria",
                                  brand: String = "FitActive",
                                  city: String = "Napoli",
                                  owner: UserAccount,
                                  into context: ModelContext) -> Gym {
        let source = GymCatalog.defaultLocation
        let layout = SpatialGrid.layout(machines: source.machines, zones: source.zones)

        let gym = Gym(brand: brand, name: name, city: city,
                      columns: SpatialGrid.columns,
                      sortIndex: owner.gyms?.count ?? 0)
        gym.owner = owner
        context.insert(gym)

        for machine in source.machines {
            guard let place = layout.placements[machine.id] else { continue }
            let equipment = GymEquipment(
                catalogItemID: machine.id,
                name: machine.name,
                subtitle: machine.subtitle,
                category: machine.category,
                gridRow: place.row,
                gridColumn: place.column,
                muscles: machine.muscles,
                howTo: machine.howTo,
                tips: machine.tips,
                uncertain: machine.uncertain
            )
            equipment.gym = gym
            context.insert(equipment)
        }

        // Le zone diventano fasce di righe: quello che serve davvero è sapere
        // "da che riga a che riga", non un rettangolo del rilievo.
        for zone in source.zones {
            let rows = source.machines
                .filter { zone.frame.contains($0.center) }
                .compactMap { layout.placements[$0.id]?.row }
            guard let first = rows.min(), let last = rows.max() else { continue }

            let stored = GymZone(name: zone.name, subtitle: zone.subtitle,
                                 symbol: zone.symbol, colorHex: zone.colorHex,
                                 startRow: first, endRow: last)
            stored.gym = gym
            context.insert(stored)
        }

        return gym
    }

    @discardableResult
    static func insertEmpty(named name: String,
                            city: String = "",
                            owner: UserAccount,
                            into context: ModelContext) -> Gym {
        let gym = Gym(brand: "", name: name, city: city,
                      columns: SpatialGrid.columns,
                      sortIndex: owner.gyms?.count ?? 0)
        gym.owner = owner
        context.insert(gym)
        return gym
    }
}

extension Gym {
    /// Traduce la palestra nel formato che la mappa disegna.
    ///
    /// Le coordinate vengono fabbricate dalla griglia — colonna × passo, riga ×
    /// passo — così l'algoritmo spaziale le rilegge esattamente nelle stesse
    /// celle. Evita di riscrivere `GymMapView`, che è il file più intrecciato
    /// del progetto.
    var asLocation: GymLocation {
        let step: CGFloat = 100
        let size: CGFloat = 90

        let machines = orderedEquipment.map { item in
            GymMachine(
                id: item.id.uuidString,
                name: item.name,
                subtitle: item.subtitle,
                category: item.machineCategory,
                rect: CGRect(x: CGFloat(item.gridColumn) * step,
                             y: CGFloat(item.gridRow) * step,
                             width: size, height: size),
                muscles: item.muscles,
                howTo: item.howTo,
                tips: item.tips,
                uncertain: item.uncertain
            )
        }

        let frames = (zones ?? []).map { zone in
            GymZoneFrame(
                id: zone.id.uuidString,
                name: zone.name,
                subtitle: zone.subtitle,
                symbol: zone.symbol,
                colorHex: zone.colorHex,
                frame: CGRect(x: 0,
                              y: CGFloat(zone.startRow) * step,
                              width: CGFloat(columns) * step,
                              height: CGFloat(max(1, zone.endRow - zone.startRow + 1)) * step)
            )
        }

        return GymLocation(id: id.uuidString, brand: brand, name: name,
                           city: city, address: address,
                           zones: frames, machines: machines)
    }

    /// La cella libera più in alto a sinistra, dove finisce il prossimo attrezzo.
    var firstFreeCell: (row: Int, column: Int) {
        let taken = Set(orderedEquipment.map { "\($0.gridRow)-\($0.gridColumn)" })
        var row = 0
        while true {
            for column in 0..<columns where !taken.contains("\(row)-\(column)") {
                return (row, column)
            }
            row += 1
        }
    }

    func equipment(atRow row: Int, column: Int) -> GymEquipment? {
        orderedEquipment.first { $0.gridRow == row && $0.gridColumn == column }
    }
}
