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
        case .member: "Vede la propria scheda e il proprio recap"
        case .trainer: "Segue gli utenti che gli sono stati assegnati"
        case .admin: "Può consultare tutti i profili"
        }
    }
}

struct AppAccount: Identifiable, Hashable {
    let id: String
    let displayName: String
    let role: UserRole
    let assignedUserIDs: [String]
    let symbol: String
}

enum AccountData {
    static let all: [AppAccount] = [
        AppAccount(id: "samuel", displayName: "Samuel", role: .member,
                   assignedUserIDs: [], symbol: "person.crop.circle.fill"),
        AppAccount(id: "raffaele", displayName: "Raffaele", role: .member,
                   assignedUserIDs: [], symbol: "person.crop.circle.fill"),
        AppAccount(id: "mariapia", displayName: "Maria Pia", role: .trainer,
                   assignedUserIDs: ["samuel", "raffaele"], symbol: "figure.strengthtraining.traditional"),
        AppAccount(id: "admin", displayName: "Amministratore", role: .admin,
                   assignedUserIDs: [], symbol: "person.badge.key.fill")
    ]

    static func account(id: String?) -> AppAccount? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
