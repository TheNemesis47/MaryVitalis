import SwiftData
import SwiftUI

@main
struct MaryVitalisApp: App {
    private let container = AppDatabase.shared

    @StateObject private var library = ExerciseLibrary.shared
    @StateObject private var store: WorkoutStore
    @StateObject private var profile: ProfileStore
    @StateObject private var cloud: CloudSync

    init() {
        // Prima di tutto: Auth e Firestore non si possono toccare finché
        // Firebase non è configurato.
        FirebaseService.configure()

        let context = AppDatabase.shared.mainContext
        // Gira una volta sola: porta dentro SwiftData i dati che vivevano in
        // `UserDefaults` e crea i profili storici.
        LegacyMigrator.runIfNeeded(context: context)
        let profileStore = ProfileStore(context: context)
        let cloudSync = CloudSync(context: context)
        let workoutStore = WorkoutStore(context: context)
        profileStore.cloud = cloudSync
        workoutStore.cloud = cloudSync
        // Quello che arriva dal cloud finisce in SwiftData, ma le viste
        // guardano gli store: senza questo rimbalzo, un cliente che accetta
        // resta invisibile al trainer fino al riavvio.
        cloudSync.onRemoteChange = { [weak profileStore, weak workoutStore] in
            profileStore?.objectWillChange.send()
            workoutStore?.refresh()
        }

        _store = StateObject(wrappedValue: workoutStore)
        _profile = StateObject(wrappedValue: profileStore)
        _cloud = StateObject(wrappedValue: cloudSync)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(store)
                .environmentObject(profile)
                .environmentObject(cloud)
                .preferredColorScheme(.dark)
                .tint(Theme.defaultAccent)
                .task {
                    // A quest'ora nessun allenamento è in corso: la sessione
                    // vive in memoria e l'app è appena partita. Quello che
                    // trova acceso è avanzato da un'app chiusa a metà.
                    WorkoutActivityManager.endOrphans()
                    RestAlarm.cancel()
                    store.publishWidgetSnapshot()
                    // L'accesso con Apple può essere stato revocato dalle
                    // impostazioni di iOS mentre l'app era chiusa.
                    await profile.validateAppleCredentialIfNeeded()
                    // Riprende la sincronizzazione di chi era già connesso.
                    if let account = profile.account, account.firebaseUID != nil {
                        await cloud.start(for: account)
                    }
                }
        }
        .modelContainer(container)
    }
}
