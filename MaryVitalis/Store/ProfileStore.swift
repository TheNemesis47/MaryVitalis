import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var signedInAccountID: String?
    @Published private(set) var selectedUserID: String {
        didSet { MaryVitalisShared.selectedUserID = selectedUserID }
    }

    init() {
        let restoredAccount = AccountData.account(id: SecureSessionStore.loadAccountID())
        signedInAccountID = restoredAccount?.id
        let saved = MaryVitalisShared.selectedUserID
        let allowed = restoredAccount.map(Self.routineIDs(for:)) ?? []
        selectedUserID = allowed.contains(saved) ? saved : (allowed.first ?? RoutineData.samuel.id)
    }

    var isSignedIn: Bool { account != nil }

    var account: AppAccount? {
        AccountData.account(id: signedInAccountID)
    }

    var availableRoutines: [Routine] {
        guard let account else { return [] }
        let allowed = Set(Self.routineIDs(for: account))
        return RoutineData.all.filter { allowed.contains($0.id) }
    }

    var selectedRoutine: Routine {
        RoutineData.routine(id: selectedUserID) ?? availableRoutines.first ?? RoutineData.samuel
    }

    func signIn(accountID: String) {
        guard let account = AccountData.account(id: accountID) else { return }
        SecureSessionStore.saveAccountID(account.id)
        signedInAccountID = account.id

        let allowed = Self.routineIDs(for: account)
        let previous = MaryVitalisShared.selectedUserID
        selectedUserID = allowed.contains(previous) ? previous : (allowed.first ?? RoutineData.samuel.id)
    }

    func selectUser(_ userID: String) {
        guard availableRoutines.contains(where: { $0.id == userID }) else { return }
        selectedUserID = userID
    }

    func signOut() {
        SecureSessionStore.clear()
        signedInAccountID = nil
    }

    private static func routineIDs(for account: AppAccount) -> [String] {
        switch account.role {
        case .member:
            return RoutineData.routine(id: account.id) == nil ? [] : [account.id]
        case .trainer:
            let ids = Set(account.assignedUserIDs + [account.id])
            return RoutineData.all.map(\.id).filter { ids.contains($0) }
        case .admin:
            return RoutineData.all.map(\.id)
        }
    }
}
