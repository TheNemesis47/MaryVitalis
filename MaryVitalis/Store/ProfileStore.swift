import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published var selectedUserID: String {
        didSet { MaryVitalisShared.selectedUserID = selectedUserID }
    }

    init() {
        let saved = MaryVitalisShared.selectedUserID
        selectedUserID = RoutineData.routine(id: saved) == nil ? RoutineData.samuel.id : saved
    }

    var selectedRoutine: Routine {
        RoutineData.routine(id: selectedUserID) ?? RoutineData.samuel
    }
}
