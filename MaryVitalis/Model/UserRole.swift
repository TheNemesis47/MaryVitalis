import Foundation

enum UserRole: String, Codable, CaseIterable {
    case member
    case trainer
    case admin

    var title: String {
        switch self {
        case .member: "Utente"
        case .trainer: "Trainer"
        case .admin: "Admin"
        }
    }

    var detail: String {
        switch self {
        case .member: "Vede le proprie schede e il proprio recap"
        case .trainer: "Segue i clienti assegnati"
        case .admin: "Può consultare tutti i profili"
        }
    }
}
