import SwiftUI

enum Tab: Hashable {
    case home, esercizi, schede, mappa, recap
}

struct RootView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: WorkoutStore

    @State private var tab: Tab = .home
    @State private var routinePath: [String] = []
    /// Filtro iniziale passato dalla home quando si tocca un distretto.
    @State private var exercisePreset: ExercisesView.Preset?

    var body: some View {
        Group {
            if profile.isSignedIn {
                mainTabs
            } else {
                LoginView()
            }
        }
        .onAppear { activateSelectedUser() }
        .onChange(of: profile.selectedUserID) { _, _ in activateSelectedUser() }
        .onChange(of: profile.signedInAccountID) { _, _ in activateSelectedUser() }
    }

    private var mainTabs: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(openBodyPart: { part in
                    exercisePreset = .bodyPart(part)
                    tab = .esercizi
                }, openRoutine: { id in
                    routinePath = [id]
                    tab = .schede
                }, goToTab: { tab = $0 })
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)

            NavigationStack {
                ExercisesView(preset: $exercisePreset)
            }
            .tabItem { Label("Esercizi", systemImage: "figure.strengthtraining.traditional") }
            .tag(Tab.esercizi)

            NavigationStack(path: $routinePath) {
                RoutinesView()
                    .navigationDestination(for: String.self) { id in
                        if let routine = profile.availableRoutines.first(where: { $0.id == id }) {
                            RoutineDetailView(routine: routine)
                        } else {
                            EmptyStateView(icon: "🤔", title: "Scheda non trovata",
                                           message: "Il programma che cerchi non esiste (più).")
                        }
                    }
            }
            .tabItem { Label("Schede", systemImage: "list.bullet.rectangle.portrait.fill") }
            .tag(Tab.schede)

            NavigationStack {
                GymMapView()
            }
            .tabItem { Label("Mappa", systemImage: "map.fill") }
            .tag(Tab.mappa)

            NavigationStack {
                RecapView()
            }
            .tabItem { Label("Recap", systemImage: "chart.bar.fill") }
            .tag(Tab.recap)
        }
        .tint(Theme.defaultAccent)
    }

    private func activateSelectedUser() {
        guard profile.isSignedIn else { return }
        store.activateUser(profile.selectedUserID)
    }
}

/// Sfondo + tipografia comuni a tutte le pagine.
struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background { Theme.background }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Theme.bg, for: .tabBar)
    }
}

extension View {
    func pageBackground() -> some View { modifier(PageBackground()) }
}
