import Foundation
import SwiftData
import SwiftUI

/// Crea e traduce le palestre.
///
/// Il rilievo di FitActive non è più una **sede** di partenza: era la palestra
/// di una persona sola, e a chiunque altro non diceva niente. Di quel lavoro
/// resta il **catalogo** degli attrezzi — nomi, muscoli, istruzioni — da cui si
/// pesca per costruire la propria sala, cella per cella.
enum GymFactory {
    /// Gli attrezzi che l'app conosce già, con testi e istruzioni scritti.
    static var catalog: [GymMachine] { GymMap.machines }

    /// La griglia iniziale di una sede nuova: piccola, perché la si allarga
    /// con i pulsanti man mano che si mappa la sala.
    static let defaultColumns = 4
    static let defaultRows = 4

    @discardableResult
    static func insertEmpty(named name: String,
                            city: String = "",
                            owner: UserAccount,
                            into context: ModelContext) -> Gym {
        let gym = Gym(brand: "", name: name, city: city,
                      columns: defaultColumns,
                      rows: defaultRows,
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

        // Un solo riordinamento, non tre: `orderedEquipment` ordina a ogni
        // chiamata, e qui serviva per attrezzi, posizioni e passaggi.
        let items = orderedEquipment
        let machines = items.filter { !$0.isWalkway }.map { item in
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
                uncertain: item.uncertain,
                symbolName: item.symbolName
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

        let placements = Dictionary(
            items.filter { !$0.isWalkway }
                .map { ($0.id.uuidString, GymPlacement(row: $0.gridRow, column: $0.gridColumn)) },
            uniquingKeysWith: { current, _ in current }
        )

        let walkways = Set(items.filter(\.isWalkway)
            .map { GymPlacement(row: $0.gridRow, column: $0.gridColumn) })

        return GymLocation(id: id.uuidString, brand: brand, name: name,
                           city: city, address: address,
                           zones: frames, machines: machines,
                           columns: gridColumns, rows: gridRows,
                           placements: placements, walkways: walkways)
    }

    /// La cella libera più in alto a sinistra, dove finisce il prossimo attrezzo.
    var firstFreeCell: (row: Int, column: Int) {
        let taken = Set(orderedEquipment.map { "\($0.gridRow)-\($0.gridColumn)" })
        var row = 0
        while true {
            for column in 0..<gridColumns where !taken.contains("\(row)-\(column)") {
                return (row, column)
            }
            row += 1
        }
    }

    func equipment(atRow row: Int, column: Int) -> GymEquipment? {
        orderedEquipment.first { $0.gridRow == row && $0.gridColumn == column }
    }
}

extension GymFactory {
    /// Copia una sede nel profilo di qualcun altro.
    ///
    /// È una copia **per valore**: chi la riceve poi la adatta — non tutti in
    /// palestra usano gli stessi attrezzi — e chi l'ha mappata non si ritrova
    /// la propria sala modificata da altri. Se l'originale cambia, si ricondivide.
    @discardableResult
    static func copy(_ source: Gym,
                     to owner: UserAccount,
                     named name: String? = nil,
                     into context: ModelContext) -> Gym {
        let copy = Gym(
            brand: source.brand,
            name: name ?? source.name,
            city: source.city,
            address: source.address,
            columns: source.columns,
            rows: source.rows,
            sortIndex: owner.gyms?.count ?? 0,
            sourceGymID: source.id
        )
        copy.owner = owner
        context.insert(copy)

        for item in source.orderedEquipment {
            let equipment = GymEquipment(
                catalogItemID: item.catalogItemID,
                name: item.name,
                subtitle: item.subtitle,
                category: item.machineCategory,
                gridRow: item.gridRow,
                gridColumn: item.gridColumn,
                muscles: item.muscles,
                howTo: item.howTo,
                tips: item.tips,
                uncertain: item.uncertain,
                symbolName: item.symbolName,
                kind: item.cellKind
            )
            equipment.gym = copy
            context.insert(equipment)
        }

        for zone in source.zones ?? [] {
            let stored = GymZone(name: zone.name, subtitle: zone.subtitle,
                                 symbol: zone.symbol, colorHex: zone.colorHex,
                                 startRow: zone.startRow, endRow: zone.endRow)
            stored.gym = copy
            context.insert(stored)
        }

        return copy
    }
}
