import SwiftUI

/// Traduce un rilievo continuo — coordinate x/y prese in sala — nella griglia
/// a corsie che la mappa mostra.
///
/// Stava dentro `GymMapView`. È uscito perché ora serve anche altrove: quando
/// si crea una palestra dal catalogo bisogna sapere in che riga e colonna
/// finisce ogni attrezzo, e due copie della stessa logica divergono sempre.
enum SpatialGrid {
    static let columns = 4

    struct Layout {
        /// [id attrezzo: posizione]
        let placements: [String: (row: Int, column: Int)]
        /// Altezza di ogni riga, ricavata dalla distanza fra le fasce nel rilievo.
        let rowHeights: [CGFloat]
        var rowCount: Int { rowHeights.count }
    }

    static func layout(machines: [GymMachine], zones: [GymZoneFrame]) -> Layout {
        let bounds = self.bounds(machines: machines, zones: zones)
        let rows = self.rows(for: machines, bounds: bounds)

        var placements: [String: (row: Int, column: Int)] = [:]
        for (rowIndex, row) in rows.enumerated() {
            let ordered = row.sorted { $0.center.x < $1.center.x }
            for (column, machine) in zip(assignedColumns(for: ordered, bounds: bounds), ordered) {
                placements[machine.id] = (rowIndex, column)
            }
        }

        let heights = rows.indices.map { height(at: $0, rows: rows) }
        return Layout(placements: placements, rowHeights: heights)
    }

    // MARK: - Righe

    /// Raggruppa gli attrezzi che nel rilievo stanno sulla stessa fascia
    /// orizzontale. La tolleranza è proporzionale all'altezza della palestra,
    /// così vale anche per sedi rilevate con scale diverse.
    private static func rows(for machines: [GymMachine], bounds: CGRect) -> [[GymMachine]] {
        let tolerance = max(12, bounds.height * 0.03)
        let ordered = machines.sorted {
            if abs($0.center.y - $1.center.y) > 0.5 { return $0.center.y < $1.center.y }
            return $0.center.x < $1.center.x
        }

        var rows: [[GymMachine]] = []
        for machine in ordered {
            if let lastIndex = rows.indices.last {
                let row = rows[lastIndex]
                let averageY = row.map(\.center.y).reduce(0, +) / CGFloat(row.count)
                if abs(machine.center.y - averageY) <= tolerance, row.count < columns {
                    rows[lastIndex].append(machine)
                    continue
                }
            }
            rows.append([machine])
        }
        return rows
    }

    private static func height(at index: Int, rows: [[GymMachine]]) -> CGFloat {
        guard index + 1 < rows.count else { return 108 }
        let currentY = rows[index].map(\.center.y).reduce(0, +) / CGFloat(rows[index].count)
        let nextY = rows[index + 1].map(\.center.y).reduce(0, +) / CGFloat(rows[index + 1].count)
        return min(144, max(104, max(1, nextY - currentY) * 2.35))
    }

    // MARK: - Colonne

    /// Sceglie quali corsie occupare minimizzando lo scarto dalle X originali.
    /// Sinistra/sinistra/destra produce [0, 1, 3], lasciando volutamente vuota
    /// la terza: gli spazi del rilievo restano spazi.
    private static func assignedColumns(for machines: [GymMachine], bounds: CGRect) -> [Int] {
        guard !machines.isEmpty else { return [] }
        let width = max(1, bounds.width)
        let targets = machines.map { machine in
            min(CGFloat(columns - 1),
                max(0, ((machine.center.x - bounds.minX) / width) * CGFloat(columns) - 0.5))
        }

        return combinations(selecting: machines.count).min {
            score($0, targets: targets) < score($1, targets: targets)
        } ?? Array(0..<machines.count)
    }

    private static func score(_ assignment: [Int], targets: [CGFloat]) -> CGFloat {
        zip(assignment, targets).reduce(0) { total, pair in
            let distance = CGFloat(pair.0) - pair.1
            return total + distance * distance
        }
    }

    private static func combinations(selecting count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        guard count < columns else { return [Array(0..<columns)] }

        var result: [[Int]] = []
        func build(_ current: [Int], from start: Int) {
            if current.count == count {
                result.append(current)
                return
            }
            for next in start..<columns {
                build(current + [next], from: next + 1)
            }
        }
        build([], from: 0)
        return result
    }

    private static func bounds(machines: [GymMachine], zones: [GymZoneFrame]) -> CGRect {
        let zoneBounds = zones.reduce(CGRect.null) { $0.union($1.frame) }
        if !zoneBounds.isNull, zoneBounds.width > 0, zoneBounds.height > 0 {
            return zoneBounds
        }
        return machines.reduce(CGRect.null) { $0.union($1.rect) }
    }
}
