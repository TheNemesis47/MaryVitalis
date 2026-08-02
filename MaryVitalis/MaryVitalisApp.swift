import SwiftUI

@main
struct MaryVitalisApp: App {
    @StateObject private var library = ExerciseLibrary.shared
    @StateObject private var store = WorkoutStore()
    @StateObject private var profile = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(store)
                .environmentObject(profile)
                .preferredColorScheme(.dark)
                .tint(Theme.defaultAccent)
                .task {
                    store.publishWidgetSnapshot(selectedUserID: profile.selectedUserID)
                }
        }
    }
}
