import SwiftUI

/// Un attrezzo posizionato sulla piantina.
struct GymMachine: Identifiable, Hashable {
    enum Category: String, CaseIterable, Hashable {
        case forza = "Macchine isotoniche"
        case cavi = "Cavi e colonne"
        case cardio = "Cardio"
        case liberi = "Pesi liberi e corpo libero"
        case altro = "Altro"

        var color: Color {
            switch self {
            case .forza:  return Color(hex: "#38bdf8")
            case .cavi:   return Color(hex: "#a78bfa")
            case .cardio: return Color(hex: "#fb7185")
            case .liberi: return Color(hex: "#fbbf24")
            case .altro:  return Color(hex: "#4ade80")
            }
        }

        var symbol: String {
            switch self {
            case .forza:  return "figure.strengthtraining.functional"
            case .cavi:   return "figure.cooldown"
            case .cardio: return "heart.fill"
            case .liberi: return "dumbbell.fill"
            case .altro:  return "questionmark.circle"
            }
        }
    }

    let id: String
    let name: String
    /// Marca o dicitura riportata sull'attrezzo.
    let subtitle: String?
    let category: Category
    /// Posizione nella pianta della sede, espressa nelle sue coordinate locali.
    let rect: CGRect
    let muscles: [String]
    /// Come si usa, passo per passo.
    let howTo: [String]
    /// Note pratiche o avvertenze.
    let tips: [String]
    /// `true` quando la mappa originale segnalava l'attrezzo come non identificato.
    var uncertain: Bool = false
    /// L'icona scelta a mano, quando c'è: il nome di un `EquipmentIcon`.
    var symbolName: String?

    /// Quella da disegnare sulla pianta. Per gli attrezzi del catalogo nessuno
    /// l'ha mai scelta, e si deduce da nome e muscoli.
    var icon: EquipmentIcon {
        symbolName.flatMap(EquipmentIcon.init(rawValue:))
            ?? .guessed(id: id, name: name, muscles: muscles)
    }

    var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }

    static func == (lhs: GymMachine, rhs: GymMachine) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
