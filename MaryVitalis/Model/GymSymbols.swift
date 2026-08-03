import UIKit

/// Le icone fra cui scegliere quando si crea un attrezzo che l'app non conosce.
///
/// Il catalogo disegna ogni postazione con una sagoma vista dall'alto, ma le
/// sagome esistono solo per gli attrezzi che qualcuno ha già descritto. Un
/// attrezzo inventato da chi mappa la sala finiva tutto uguale: stesso
/// rettangolo per il tapis, per la panca e per lo spazio dello stretching.
/// Un'icona scelta a mano vale più di una sagoma sbagliata.
enum GymSymbols {
    struct Group: Identifiable {
        let id: String
        let title: String
        let symbols: [String]
    }

    /// Solo simboli che esistono davvero sul sistema: una voce sbagliata
    /// lascerebbe una cella vuota senza dire perché.
    static let groups: [Group] = raw.compactMap { group in
        let available = group.symbols.filter { UIImage(systemName: $0) != nil }
        return available.isEmpty ? nil : Group(id: group.id, title: group.title,
                                               symbols: available)
    }

    static var all: [String] { groups.flatMap(\.symbols) }

    private static let raw: [Group] = [
        Group(id: "forza", title: "Forza", symbols: [
            "figure.strengthtraining.traditional",
            "figure.strengthtraining.functional",
            "dumbbell.fill",
            "scalemass.fill",
            "figure.core.training",
            "figure.step.training"
        ]),
        Group(id: "cardio", title: "Cardio", symbols: [
            "figure.run",
            "figure.walk",
            "figure.indoor.cycle",
            "figure.outdoor.cycle",
            "figure.elliptical",
            "figure.stair.stepper",
            "figure.rower",
            "figure.jumprope",
            "figure.mixed.cardio",
            "figure.highintensity.intervaltraining",
            "heart.fill",
            "flame.fill"
        ]),
        Group(id: "corpo-libero", title: "Corpo libero e mobilità", symbols: [
            "figure.flexibility",
            "figure.cooldown",
            "figure.yoga",
            "figure.pilates",
            "figure.boxing",
            "figure.climbing",
            "figure.pool.swim"
        ]),
        Group(id: "sala", title: "Sala", symbols: [
            "bed.double.fill",
            "chair.fill",
            "square.grid.2x2.fill",
            "rectangle.fill",
            "capsule.fill",
            "cylinder.fill",
            "cube.fill",
            "circle.grid.cross.fill",
            "arrow.up.and.down",
            "arrow.left.and.right",
            "timer",
            "stopwatch.fill",
            "drop.fill",
            "gearshape.fill",
            "wrench.and.screwdriver.fill",
            "questionmark.circle.fill"
        ])
    ]
}
