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
    /// Chiamarlo per ogni voce di un elenco da milletrecento significherebbe
    /// ricalcolare a ogni giro gli insiemi degli attrezzi disponibili, che si
    /// leggono scorrendo tutte le postazioni di tutte le sedi: lavoro
    /// quadratico su un elenco che cresce con l'uso.
    func availabilityFilter() -> (Exercise) -> Bool {
        let catalogIDs = availableCatalogIDs
        let icons = availableIcons

        return { exercise in
            // La famiglia di attrezzo è la strada che vale per tutti: un
            // attrezzo inventato da chi mappa la sua palestra ha un'icona, e
            // quella è la sua famiglia.
            let required = EquipmentIcon.required(forExerciseNamed: exercise.name,
                                                  equipment: exercise.equipment)
            if required.isEmpty { return true }
            if !required.isDisjoint(with: icons) { return true }

            // Scorciatoia esatta per chi ha importato una sede già mappata:
            // lì la macchina precisa si conosce per nome.
            return GymMap.machines(for: exercise.name)
                .contains { catalogIDs.contains($0.id) }
        }
    }

    /// Per il caso singolo. Nei cicli si usa `availabilityFilter()`.
    func canPerform(_ exercise: Exercise) -> Bool {
        availabilityFilter()(exercise)
    }

}
