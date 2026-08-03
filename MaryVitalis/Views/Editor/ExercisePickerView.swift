import SwiftUI

/// Scelta di un esercizio dal database. Stessi filtri della schermata Esercizi,
/// ma in modalità selezione: si tocca e si torna indietro.
struct ExercisePickerView: View {
    let accent: Color
    var onPick: (Exercise) -> Void

    @EnvironmentObject private var library: ExerciseLibrary
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var bodyPart = ""
    @State private var target = ""
    @State private var equipment = ""
    @State private var onlyMine = false

    private var results: [Exercise] {
        let all = library.filter(search: search, bodyPart: bodyPart,
                                 target: target, equipment: equipment)
        // "Attrezzo" qui sopra è come lo chiama il database — bilanciere, cavo,
        // macchina. Questo invece è quello che c'è **in sala**: scrivere una
        // scheda con un attrezzo che non si ha è il modo più veloce per farla
        // saltare al primo allenamento.
        guard onlyMine, profile.hasMappedEquipment else { return all }
        return all.filter(profile.availabilityFilter())
    }

    /// Il database ha 1324 voci: mostrarle tutte insieme non serve a nessuno e
    /// rallenta la lista. Chi cerca qualcosa di preciso usa i filtri.
    private var displayed: [Exercise] { Array(results.prefix(80)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters

                if library.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                    Spacer()
                } else if displayed.isEmpty {
                    EmptyStateView(icon: "🔍", title: "Nessun esercizio",
                                   message: "Prova con un altro termine o togli qualche filtro.")
                        .padding(.top, 30)
                    Spacer()
                } else {
                    List(displayed) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            row(exercise)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background { Theme.background }
            .navigationTitle("Scegli esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(results.count > displayed.count
                         ? "\(displayed.count) di \(results.count)"
                         : "\(results.count) esercizi")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .presentationBackground(Theme.bg)
    }

    private var filters: some View {
        VStack(spacing: 10) {
            TextField("Cerca un esercizio", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if profile.hasMappedEquipment {
                        Button {
                            onlyMine.toggle()
                            Feedback.tap()
                        } label: {
                            Chip(label: onlyMine ? "✓ Solo i miei attrezzi" : "Solo i miei attrezzi",
                                 active: onlyMine, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                    FilterMenu(title: "Distretto", all: "Tutti i distretti",
                               options: library.bodyParts, selection: $bodyPart)
                    FilterMenu(title: "Muscolo", all: "Tutti i muscoli",
                               options: library.targets(for: bodyPart.isEmpty ? nil : bodyPart),
                               selection: $target)
                    FilterMenu(title: "Attrezzo", all: "Tutti gli attrezzi",
                               options: library.equipment, selection: $equipment)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: exercise.imageURL)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                Text([exercise.muscleGroup, exercise.target, exercise.equipment]
                    .compactMap { $0 }
                    .prefix(2)
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(accent)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
