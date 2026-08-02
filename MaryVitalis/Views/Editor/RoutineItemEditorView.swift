import SwiftUI

/// Serie, ripetizioni, cardio e recupero di un singolo esercizio.
struct RoutineItemEditorView: View {
    @Bindable var item: RoutineItem
    let accent: Color

    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var library: ExerciseLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var isCardio: Bool
    @State private var minutes: Int

    init(item: RoutineItem, accent: Color) {
        self.item = item
        self.accent = accent
        _isCardio = State(initialValue: item.isCardio)
        _minutes = State(initialValue: item.minutes ?? 10)
    }

    private var exercise: Exercise? { library.find(item.exerciseQuery) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        RemoteImage(url: exercise?.imageURL)
                            .frame(width: 64, height: 64)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(exercise?.name ?? item.accentFallbackName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                }

                Section {
                    Picker("Tipo", selection: $isCardio) {
                        Text("A serie").tag(false)
                        Text("Cardio a tempo").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(isCardio
                         ? "Un blocco cardio si segna come fatto e ha un timer sui minuti previsti."
                         : "Le serie si segnano in ordine durante l'allenamento.")
                }

                if isCardio {
                    Section("Durata") {
                        Stepper(value: $minutes, in: 1...180, step: 5) {
                            Text("\(minutes) minuti")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                } else {
                    Section("Carico") {
                        Stepper(value: $item.sets, in: 1...12) {
                            Text(Fmt.plural(item.sets, "serie", "serie"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        LabeledContent("Ripetizioni") {
                            TextField("12", text: repsBinding)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    LabeledContent("Nota") {
                        TextField("Es. movimento lento", text: noteBinding)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Recupero", selection: restBinding) {
                        Text("Come la scheda").tag(0)
                        ForEach(WorkoutStore.restOptions, id: \.self) { seconds in
                            Text("\(seconds)s").tag(seconds)
                        }
                    }
                } footer: {
                    Text("Il recupero specifico vale solo per questo esercizio.")
                }

                Section {
                    Text(item.details)
                        .font(.footnote)
                        .foregroundStyle(Theme.textDim)
                } header: {
                    Text("Come apparirà")
                }
            }
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle("Esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { commit(); dismiss() }
                }
            }
        }
        .presentationBackground(Theme.bg)
    }

    private var repsBinding: Binding<String> {
        Binding(get: { item.repsText ?? "" },
                set: { item.repsText = $0.isEmpty ? nil : $0 })
    }

    private var noteBinding: Binding<String> {
        Binding(get: { item.note ?? "" },
                set: { item.note = $0.isEmpty ? nil : $0 })
    }

    private var restBinding: Binding<Int> {
        Binding(get: { item.restOverrideSeconds ?? 0 },
                set: { item.restOverrideSeconds = $0 == 0 ? nil : $0 })
    }

    private func commit() {
        item.minutes = isCardio ? minutes : nil
        if isCardio { item.sets = 1 }
        // Da adesso comandano i campi strutturati: la riga di testo con cui
        // l'esercizio era nato non descrive più quello che c'è scritto qui.
        item.rawDetails = nil
        if let routine = item.day?.routine { profile.save(routine) }
    }
}
