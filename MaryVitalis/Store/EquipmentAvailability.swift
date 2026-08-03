import Foundation

/// Gli attrezzi che una persona ha davvero, e cosa ci si può fare.
///
/// Il database degli esercizi ne conosce milletrecento, ma nessuno li può fare
/// tutti: si fa quello che c'è in sala. Il collegamento fra i due mondi esiste
/// già — ogni postazione mappata sa da quale voce di catalogo viene — e questo
/// è il posto dove si usa per rispondere a una domanda pratica: *questo
/// esercizio, io, lo posso fare?*
///
/// Non è un magazzino separato da riempire a mano: gli attrezzi di una persona
/// **sono** quelli che ha messo nelle sue sedi. Mapparli una volta serve alla
/// mappa e serve a scrivere le schede.
extension ProfileStore {
    /// Una voce del catalogo personale: un tipo di attrezzo, quante copie, e
    /// in quali sedi.
    struct EquipmentEntry: Identifiable {
        let id: String
        let sample: GymEquipment
        let count: Int
        let gymNames: [String]

        var name: String {
            sample.name.replacingOccurrences(of: #"\s+\d+$"#, with: "",
                                             options: .regularExpression)
        }
    }

    /// Tutte le postazioni delle sue sedi, i passaggi esclusi.
    var myEquipment: [GymEquipment] {
        gyms.flatMap { ($0.equipment ?? []).filter { !$0.isWalkway } }
    }

    /// Il catalogo personale: una voce per tipo, non una per esemplare.
    var equipmentCatalog: [EquipmentEntry] {
        var byKey: [String: [GymEquipment]] = [:]
        for item in myEquipment {
            byKey[item.reuseKey, default: []].append(item)
        }
        return byKey.compactMap { key, items in
            guard let sample = items.first else { return nil }
            let names = Set(items.compactMap { $0.gym?.displayName })
            return EquipmentEntry(id: key, sample: sample, count: items.count,
                                  gymNames: names.sorted())
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Gli identificativi di catalogo presenti nelle sue sedi.
    var availableCatalogIDs: Set<String> {
        Set(myEquipment.compactMap(\.catalogItemID))
    }

    /// Le icone presenti: servono a riconoscere gli attrezzi generici — i
    /// manubri, il bilanciere, i cavi — che negli esercizi non arrivano come
    /// una macchina precisa ma come una famiglia.
    var availableIcons: Set<EquipmentIcon> {
        Set(myEquipment.map(\.icon))
    }

    var hasMappedEquipment: Bool { !myEquipment.isEmpty }

    /// Un filtro costruito **una volta** e riusato per tutti gli esercizi.
    ///
    /// Chiamare `canPerform` in un ciclo su milletrecento voci significava
    /// ricalcolare a ogni giro gli insiemi degli attrezzi disponibili, che si
    /// leggono scorrendo tutte le postazioni di tutte le sedi: un lavoro
    /// quadratico su un elenco che cresce con l'uso. Qui gli insiemi si
    /// costruiscono una volta e restano nella chiusura.
    func availabilityFilter() -> (Exercise) -> Bool {
        let catalogIDs = availableCatalogIDs
        let icons = availableIcons

        return { exercise in
            let equipment = (exercise.equipment ?? "").lowercased()
            // Tre strade, dalla più precisa alla più larga: la macchina esatta,
            // la famiglia di attrezzo, e il corpo libero — che non chiede
            // niente a nessuno.
            if equipment.contains("body weight") || equipment.contains("corpo libero") {
                return true
            }
            if GymMap.machines(for: exercise.name).contains(where: { catalogIDs.contains($0.id) }) {
                return true
            }
            return Self.iconFamilies(for: equipment).contains(where: icons.contains)
        }
    }

    /// Per il caso singolo. Nei cicli si usa `availabilityFilter()`.
    func canPerform(_ exercise: Exercise) -> Bool {
        availabilityFilter()(exercise)
    }

    /// Da come il database chiama l'attrezzo alle icone che lo rappresentano.
    private static func iconFamilies(for equipment: String) -> Set<EquipmentIcon> {
        switch true {
        case equipment.contains("dumbbell"): [.dumbbellRack, .bench, .benchRack]
        case equipment.contains("kettlebell"): [.kettlebell, .dumbbellRack]
        case equipment.contains("barbell"), equipment.contains("ez barbell"):
            [.plateRack, .benchRack, .smithMachine]
        case equipment.contains("smith"): [.smithMachine]
        case equipment.contains("cable"): [.cableColumn]
        case equipment.contains("leverage"), equipment.contains("sled"):
            [.chestPress, .shoulderPress, .legPress, .hackSquat, .latPulldown,
             .seatedRow, .pecFly, .lateralRaise, .legExtension, .legCurl,
             .abductor, .glute, .abCrunch, .calf, .pullover]
        case equipment.contains("assisted"): [.dipAssist]
        case equipment.contains("stationary bike"): [.bike]
        case equipment.contains("elliptical"): [.elliptical]
        case equipment.contains("treadmill"): [.treadmill]
        case equipment.contains("stepmill"), equipment.contains("stair"): [.stepper]
        case equipment.contains("rope"), equipment.contains("band"),
             equipment.contains("ball"), equipment.contains("roller"),
             equipment.contains("bosu"), equipment.contains("wheel"):
            [.mat, .stretchArea]
        default: []
        }
    }
}
