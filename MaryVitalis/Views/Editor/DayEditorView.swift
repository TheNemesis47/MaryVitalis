import SwiftUI

/// Gli esercizi di un giorno: aggiunta dal database, riordino, rimozione.
struct DayEditorView: View {
    @Bindable var day: RoutineDay
    let accent: Color

    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var library: ExerciseLibrary

    @State private var showPicker = false
    @State private var editing: RoutineItem?

    var body: some View {
        List {
            Section("Giorno") {
                LabeledContent("Nome") {
                    TextField("Es. Petto e spalle", text: $day.name)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Giorno della settimana", selection: weekdayBinding) {
                    Text("Libero").tag(0)
                    ForEach(1...7, id: \.self) { index in
                        Text(Self.weekdayName(index)).tag(index)
                    }
                }
            }

            Section {
                ForEach(day.orderedItems, id: \.id) { item in
                    Button { editing = item } label: { itemRow(item) }
                        .buttonStyle(.plain)
                }
                .onMove { profile.moveItems(in: day, from: $0, to: $1) }
                .onDelete { offsets in
                    let items = day.orderedItems
                    for index in offsets where items.indices.contains(index) {
                        profile.delete(items[index])
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Aggiungi un esercizio", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Esercizi (\(day.orderedItems.count))")
            } footer: {
                if day.orderedItems.isEmpty {
                    Text("Nessun esercizio. Aggiungine uno dal database di \(library.all.count) voci.")
                } else {
                    Text("Tocca un esercizio per cambiare serie, ripetizioni e recupero.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { Theme.background }
        .navigationTitle(day.name.isEmpty ? "Giorno" : day.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onSettled(day.name) {
            if let routine = day.routine { profile.save(routine) }
        }
        .onDisappear {
            if let routine = day.routine { profile.save(routine) }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(accent: accent) { exercise in
                profile.addItem(to: day, query: exercise.name, name: exercise.name)
                Feedback.success()
            }
            .environmentObject(library)
        }
        .sheet(isPresented: Binding(get: { editing != nil },
                                    set: { if !$0 { editing = nil } })) {
            if let editing {
                RoutineItemEditorView(item: editing, accent: accent)
                    .environmentObject(profile)
                    .environmentObject(library)
            }
        }
    }

    private var weekdayBinding: Binding<Int> {
        Binding(get: { day.preferredWeekday ?? 0 },
                set: { day.preferredWeekday = $0 == 0 ? nil : $0 })
    }

    private func itemRow(_ item: RoutineItem) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: library.find(item.exerciseQuery)?.imageURL)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(library.find(item.exerciseQuery)?.name ?? item.accentFallbackName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                Text(item.details)
                    .font(.caption)
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textFaint)
        }
    }

    /// 1 = domenica, come `Calendar`.
    static func weekdayName(_ index: Int) -> String {
        let names = ["Domenica", "Lunedì", "Martedì", "Mercoledì",
                     "Giovedì", "Venerdì", "Sabato"]
        return names.indices.contains(index - 1) ? names[index - 1] : "Libero"
    }
}
