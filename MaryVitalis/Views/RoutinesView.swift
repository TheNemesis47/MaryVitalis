import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(eyebrow: "Programmi", title: "Le schede",
                           subtitle: "Ogni scheda è un programma settimanale completo: giorno per giorno, esercizio per esercizio, con serie, ripetizioni e note di esecuzione.")

                ForEach(profile.availableRoutines) { routine in
                    NavigationLink(value: routine.id) {
                        RoutineCard(routine: routine, daysDone: store.completedDays(routine: routine)) {}
                            .allowsHitTesting(false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .pageBackground()
        .navigationTitle("Schede")
        .navigationBarTitleDisplayMode(.inline)
    }
}
