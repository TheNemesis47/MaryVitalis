import SwiftUI

/// Costruzione di una scheda: intestazione e giorni.
///
/// Il numero di giorni è libero — da uno a quanti ne servono — perché "giorno 1,
/// 2, 3" era una scelta delle tre schede scritte a mano, non una regola.
struct RoutineEditorView: View {
    @Bindable var routine: Routine

    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var library: ExerciseLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDeleteDay: RoutineDay?

    private var accent: Color { routine.accent }
    private var isForSomeoneElse: Bool {
        routine.owner?.id != profile.signedInAccountID
    }

    var body: some View {
        List {
            if isForSomeoneElse, let owner = routine.owner {
                Section {
                    Label("Stai scrivendo la scheda di \(owner.displayName). La troverà sul suo telefono.",
                          systemImage: "person.2.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "#f59e0b"))
                }
            }

            Section("Scheda") {
                LabeledContent("Nome") {
                    TextField("Nome", text: $routine.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Emoji") {
                    TextField("💪", text: $routine.emoji)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                LabeledContent("Obiettivo") {
                    TextField("Es. Massa, Recupero…", text: $routine.goal)
                        .multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Descrizione").font(.subheadline).foregroundStyle(Theme.textDim)
                    TextField("A cosa serve questa scheda", text: $routine.summary,
                              axis: .vertical)
                        .lineLimit(2...5)
                }
                colorPicker
            }

            Section {
                ForEach(routine.orderedDays, id: \.id) { day in
                    NavigationLink {
                        DayEditorView(day: day, accent: accent)
                    } label: {
                        dayRow(day)
                    }
                }
                .onMove { profile.moveDays(in: routine, from: $0, to: $1) }
                .onDelete { offsets in
                    let days = routine.orderedDays
                    for index in offsets where days.indices.contains(index) {
                        profile.delete(days[index])
                    }
                }

                Button {
                    profile.addDay(to: routine)
                    Feedback.tap()
                } label: {
                    Label("Aggiungi un giorno", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Giorni (\(routine.orderedDays.count))")
            } footer: {
                Text("Trascina per riordinare, scorri a sinistra per eliminare. Puoi metterne quanti ne servono.")
            }
        }
        .scrollContentBackground(.hidden)
        .background { Theme.background }
        .navigationTitle("Modifica scheda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onChange(of: routine.name) { _, _ in profile.save(routine) }
        .onChange(of: routine.emoji) { _, _ in profile.save(routine) }
        .onChange(of: routine.goal) { _, _ in profile.save(routine) }
        .onChange(of: routine.summary) { _, _ in profile.save(routine) }
        .onChange(of: routine.accentHex) { _, _ in profile.save(routine) }
    }

    private func dayRow(_ day: RoutineDay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day.name.isEmpty ? "Giorno senza nome" : day.name)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(Fmt.plural(day.orderedItems.count, "esercizio", "esercizi"))
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Colore").font(.subheadline).foregroundStyle(Theme.textDim)
            HStack(spacing: 10) {
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        routine.accentHex = hex
                        Feedback.tap()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(Theme.text,
                                                lineWidth: routine.accentHex == hex ? 2.5 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colore \(hex)")
                }
                Spacer(minLength: 0)
            }
        }
    }

    private static let palette = [
        "#38bdf8", "#fb7185", "#a78bfa", "#4ade80", "#fbbf24", "#f472b6", "#22d3ee"
    ]
}
