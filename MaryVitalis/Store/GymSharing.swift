import Foundation
import SwiftData

/// Condivisione delle sedi.
///
/// Mappare una palestra è lavoro: cinquanta attrezzi, muscoli, istruzioni. Ha
/// senso che si faccia una volta sola e poi giri — fra un trainer e i suoi
/// clienti, o fra chi frequenta la stessa sala.
///
/// Chi riceve una sede ne ottiene una **copia**: la adatta a sé senza toccare
/// l'originale, e chi l'ha mappata non si ritrova la propria sala cambiata da
/// altri. Se l'originale migliora, si ricondivide.
extension ProfileStore {
    /// La sede scelta nella mappa. È una preferenza di dispositivo, non un dato
    /// del profilo: la stessa persona in trasferta usa un'altra sala.
    static let selectedGymKey = "mv:selected-gym"

    var gyms: [Gym] {
        (viewedAccount?.gyms ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// La sede attiva del profilo consultato, o la prima che ha.
    var activeGym: Gym? {
        let selected = UserDefaults.standard.string(forKey: Self.selectedGymKey)
            .flatMap(UUID.init(uuidString:))
        return gyms.first { $0.id == selected } ?? gyms.first
    }

    /// Gli attrezzi della **sua** sala su cui si fa questo esercizio.
    /// Senza sede mappata non si inventa niente: la lista resta vuota e la UI
    /// lo dice, invece di indicare la macchina di una palestra di qualcun altro.
    func machines(for query: String) -> [GymMachine] {
        guard let activeGym else { return [] }
        return GymCatalog.machines(for: query, in: activeGym)
    }

    /// Cancella la sede, dal telefono e dal cloud.
    ///
    /// Senza la seconda metà tornava indietro da sola: la copia su Firestore
    /// restava, e la sincronizzazione successiva la reimportava come se fosse
    /// nuova. È il motivo per cui "Elimina" sembrava non funzionare.
    func delete(_ gym: Gym) {
        let id = gym.id
        let code = gym.shareCode
        let wasShared = gym.isShared
        let wasSelected = UserDefaults.standard.string(forKey: Self.selectedGymKey) == id.uuidString

        context.delete(gym)
        try? context.save()
        objectWillChange.send()

        if wasSelected {
            UserDefaults.standard.removeObject(forKey: Self.selectedGymKey)
        }

        if let cloud {
            Task {
                await cloud.deleteGym(id: id)
                if wasShared, !code.isEmpty { await cloud.releaseGymCode(code) }
            }
        }
    }

    enum GymError: LocalizedError {
        case invalidCode
        case unknownCode
        case notYourClient
        case notYourGym

        var errorDescription: String? {
            switch self {
            case .invalidCode: "Il codice deve avere \(InviteCode.length) caratteri."
            case .unknownCode: "Nessuna palestra con questo codice."
            case .notYourClient: "Puoi assegnare una sede solo ai tuoi clienti."
            case .notYourGym: "Questa sede non è tua."
            }
        }
    }

    /// Pubblica la sede e le assegna un codice da dettare.
    @discardableResult
    func shareGym(_ gym: Gym) async throws -> String {
        guard gym.owner?.id == signedInAccountID else { throw GymError.notYourGym }

        if gym.shareCode.isEmpty {
            gym.shareCode = InviteCode.generate()
        }
        gym.isShared = true
        gym.updatedAt = .now
        try context.save()
        objectWillChange.send()

        if let cloud, let ownerUID = gym.owner?.firebaseUID {
            await cloud.pushGym(gym, ownerUID: ownerUID)
        }
        return gym.shareCode
    }

    /// Toglie la sede dalla circolazione. Le copie già fatte restano a chi le ha:
    /// sono sue, non un prestito.
    func stopSharing(_ gym: Gym) async throws {
        guard gym.owner?.id == signedInAccountID else { throw GymError.notYourGym }
        let code = gym.shareCode
        gym.isShared = false
        gym.shareCode = ""
        gym.updatedAt = .now
        try context.save()
        objectWillChange.send()

        if let cloud {
            await cloud.releaseGymCode(code)
            if let ownerUID = gym.owner?.firebaseUID {
                await cloud.pushGym(gym, ownerUID: ownerUID)
            }
        }
    }

    /// Importa la sede di qualcun altro a partire dal codice.
    @discardableResult
    func importGym(code rawCode: String, for owner: UserAccount) async throws -> Gym {
        let code = InviteCode.normalize(rawCode)
        guard InviteCode.isValid(code) else { throw GymError.invalidCode }
        guard let cloud, let remote = try await cloud.fetchSharedGym(code: code) else {
            throw GymError.unknownCode
        }

        let gym = remote.insert(owner: owner, into: context)
        try context.save()
        objectWillChange.send()

        // La copia è dell'utente: viene caricata sotto il suo nome, non resta
        // un riferimento a quella di qualcun altro.
        if let ownerUID = owner.firebaseUID {
            await cloud.pushGym(gym, ownerUID: ownerUID)
        }
        return gym
    }

    /// Il trainer assegna una propria sede a un cliente: gliene scrive una copia
    /// nel profilo, come fa con le schede.
    @discardableResult
    func assignGym(_ gym: Gym, to client: UserAccount) async throws -> Gym {
        guard let account, clients(of: account).contains(where: { $0.id == client.id }) else {
            throw GymError.notYourClient
        }
        let copy = GymFactory.copy(gym, to: client, into: context)
        try context.save()
        objectWillChange.send()

        if let cloud, let clientUID = client.firebaseUID {
            await cloud.pushGym(copy, ownerUID: clientUID)
        }
        return copy
    }
}
