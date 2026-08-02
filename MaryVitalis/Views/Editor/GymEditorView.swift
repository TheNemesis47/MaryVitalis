import SwiftData
import SwiftUI

/// Le palestre del profilo: creazione, scelta di quella attiva, modifica.
struct GymListView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("mv:selected-gym") private var selectedGymID = ""

    @State private var editing: Gym?
    @State private var deleting: Gym?

    private var owner: UserAccount? { profile.viewedAccount }
    private var gyms: [Gym] {
        (owner?.gyms ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "PALESTRE", title: "Le tue sedi",
                               subtitle: "La sede attiva è quella che vedi nella mappa durante l'allenamento.")

                    if gyms.isEmpty {
                        EmptyStateView(icon: "🗺️", title: "Nessuna sede",
                                       message: "Aggiungi la tua palestra e disponi gli attrezzi come li trovi in sala.")
                    }

                    ForEach(gyms, id: \.id) { gym in
                        gymRow(gym)
                    }

                    if owner != nil {
                        Button("＋  Crea una sede vuota") { createEmpty() }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)

                        Button("Parti da FitActive La Birreria") { createFromCatalog() }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)

                        Text("La sede di esempio arriva con i \(GymFactory.catalog.count) attrezzi già rilevati, istruzioni comprese. Puoi spostarli, rinominarli o toglierli.")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
            }
        }
        .presentationBackground(Theme.bg)
        .sheet(isPresented: Binding(get: { editing != nil },
                                    set: { if !$0 { editing = nil } })) {
            if let editing {
                NavigationStack { GymEditorView(gym: editing) }
                    .presentationBackground(Theme.bg)
            }
        }
        .alert("Eliminare \(deleting?.displayName ?? "")?",
               isPresented: Binding(get: { deleting != nil },
                                    set: { if !$0 { deleting = nil } })) {
            Button("Annulla", role: .cancel) { deleting = nil }
            Button("Elimina", role: .destructive) {
                if let deleting {
                    context.delete(deleting)
                    try? context.save()
                }
                deleting = nil
            }
        }
    }

    private func gymRow(_ gym: Gym) -> some View {
        let active = selectedGymID == gym.id.uuidString
        return Button {
            selectedGymID = gym.id.uuidString
            Feedback.tap()
        } label: {
            Panel(padding: 15, radius: Theme.rLg) {
                HStack(spacing: 13) {
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(active ? Theme.defaultAccent : Theme.textFaint)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(gym.displayName.isEmpty ? "Sede senza nome" : gym.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("\(gym.city.isEmpty ? "" : gym.city + " · ")\(Fmt.plural(gym.orderedEquipment.count, "attrezzo", "attrezzi"))")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer(minLength: 8)

                    Button { editing = gym } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textDim)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Modifica \(gym.displayName)")
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { deleting = gym } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }

    private func createEmpty() {
        guard let owner else { return }
        let gym = GymFactory.insertEmpty(named: "La mia palestra", owner: owner, into: context)
        try? context.save()
        selectedGymID = gym.id.uuidString
        editing = gym
        Feedback.success()
    }

    private func createFromCatalog() {
        guard let owner else { return }
        let gym = GymFactory.insertFromCatalog(owner: owner, into: context)
        try? context.save()
        selectedGymID = gym.id.uuidString
        Feedback.success()
    }
}

/// Disposizione degli attrezzi sulla griglia della sala.
struct GymEditorView: View {
    @Bindable var gym: Gym

    @Environment(\.modelContext) private var context

    @State private var showPicker = false
    @State private var targetCell: (row: Int, column: Int)?
    @State private var editingEquipment: GymEquipment?

    private var rows: Int { max(gym.rowCount + 1, 4) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel(padding: 15, radius: Theme.rLg) {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Nome") {
                            TextField("La mia palestra", text: $gym.name)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Insegna") {
                            TextField("Facoltativa", text: $gym.brand)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Città") {
                            TextField("Facoltativa", text: $gym.city)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Text("Pianta della sala")
                    .font(.headline)
                    .foregroundStyle(Theme.text)

                Text("Tocca una cella vuota per metterci un attrezzo, toccane uno per modificarlo. Le celle vuote restano vuote: se in sala lì non c'è niente, la mappa lo rispecchia.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)

                grid
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("Modifica sede")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: gym.name) { _, _ in try? context.save() }
        .onChange(of: gym.brand) { _, _ in try? context.save() }
        .onChange(of: gym.city) { _, _ in try? context.save() }
        .sheet(isPresented: $showPicker) {
            EquipmentPickerSheet { machine in
                addEquipment(from: machine)
            }
        }
        .sheet(isPresented: Binding(get: { editingEquipment != nil },
                                    set: { if !$0 { editingEquipment = nil } })) {
            if let editingEquipment {
                EquipmentEditorSheet(equipment: editingEquipment, gym: gym)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<gym.columns, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let item = gym.equipment(atRow: row, column: column)

        return Button {
            if let item {
                editingEquipment = item
            } else {
                targetCell = (row, column)
                showPicker = true
            }
            Feedback.tap()
        } label: {
            Group {
                if let item {
                    VStack(spacing: 5) {
                        Image(systemName: item.machineCategory.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(item.machineCategory.color)
                        Text(item.name)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(item.machineCategory.color.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(item.machineCategory.color.opacity(0.35), lineWidth: 1))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textFaint.opacity(0.5))
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background(Theme.surface.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.border.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item?.name ?? "Cella vuota, riga \(row + 1) colonna \(column + 1)")
    }

    private func addEquipment(from machine: GymMachine?) {
        let cell = targetCell ?? gym.firstFreeCell
        let equipment: GymEquipment
        if let machine {
            equipment = GymEquipment(catalogItemID: machine.id, name: machine.name,
                                     subtitle: machine.subtitle, category: machine.category,
                                     gridRow: cell.row, gridColumn: cell.column,
                                     muscles: machine.muscles, howTo: machine.howTo,
                                     tips: machine.tips, uncertain: machine.uncertain)
        } else {
            equipment = GymEquipment(name: "Nuovo attrezzo", category: .altro,
                                     gridRow: cell.row, gridColumn: cell.column)
        }
        equipment.gym = gym
        context.insert(equipment)
        try? context.save()
        targetCell = nil
        editingEquipment = machine == nil ? equipment : nil
        Feedback.success()
    }
}

/// Scelta di un attrezzo dal catalogo di sistema.
struct EquipmentPickerSheet: View {
    var onPick: (GymMachine?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var results: [GymMachine] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return GymFactory.catalog }
        return GymFactory.catalog.filter {
            $0.name.lowercased().contains(query)
                || ($0.subtitle?.lowercased().contains(query) ?? false)
                || $0.muscles.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        Label("Attrezzo personalizzato", systemImage: "square.and.pencil")
                    }
                    .listRowBackground(Theme.surface)
                } footer: {
                    Text("Se in sala hai qualcosa che non è in elenco, aggiungilo tu con nome, muscoli e istruzioni.")
                }

                Section("Catalogo (\(results.count))") {
                    ForEach(results, id: \.id) { machine in
                        Button {
                            onPick(machine)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: machine.category.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(machine.category.color)
                                    .frame(width: 36, height: 36)
                                    .background(machine.category.color.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(machine.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                        .multilineTextAlignment(.leading)
                                    if let subtitle = machine.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textFaint)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .searchable(text: $search, prompt: "Cerca un attrezzo")
            .navigationTitle("Aggiungi attrezzo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
        }
        .presentationBackground(Theme.bg)
    }
}

/// Dettagli di un attrezzo posizionato: nome, categoria, posizione, istruzioni.
struct EquipmentEditorSheet: View {
    @Bindable var equipment: GymEquipment
    let gym: Gym

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section("Attrezzo") {
                    LabeledContent("Nome") {
                        TextField("Nome", text: $equipment.name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Marca o dicitura") {
                        TextField("Facoltativa", text: Binding(
                            get: { equipment.subtitle ?? "" },
                            set: { equipment.subtitle = $0.isEmpty ? nil : $0 }))
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Categoria", selection: Binding(
                        get: { equipment.machineCategory },
                        set: { equipment.machineCategory = $0 })) {
                        ForEach(GymMachine.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }

                Section {
                    Stepper("Riga \(equipment.gridRow + 1)", value: $equipment.gridRow, in: 0...40)
                    Stepper("Colonna \(equipment.gridColumn + 1)",
                            value: $equipment.gridColumn, in: 0...(gym.columns - 1))
                } header: {
                    Text("Posizione in sala")
                } footer: {
                    if let other = gym.orderedEquipment.first(where: {
                        $0.id != equipment.id
                            && $0.gridRow == equipment.gridRow
                            && $0.gridColumn == equipment.gridColumn
                    }) {
                        Text("Attenzione: qui c'è già \(other.name). Due attrezzi nella stessa cella si sovrappongono sulla mappa.")
                            .foregroundStyle(Color(hex: "#fbbf24"))
                    }
                }

                Section("Muscoli allenati") {
                    ListEditor(items: Binding(get: { equipment.muscles },
                                              set: { equipment.muscles = $0 }),
                               placeholder: "Es. Pettorali")
                }

                Section("Come si usa") {
                    ListEditor(items: Binding(get: { equipment.howTo },
                                              set: { equipment.howTo = $0 }),
                               placeholder: "Un passaggio per riga")
                }

                Section("Avvertenze") {
                    ListEditor(items: Binding(get: { equipment.tips },
                                              set: { equipment.tips = $0 }),
                               placeholder: "Nota pratica")
                }

                Section {
                    Toggle("Da identificare", isOn: $equipment.uncertain)
                } footer: {
                    Text("Segnala gli attrezzi di cui non sei sicuro: nella scheda comparirà un avviso.")
                }

                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Togli dalla sala", systemImage: "trash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { Theme.background }
            .navigationTitle(equipment.name.isEmpty ? "Attrezzo" : equipment.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { try? context.save(); dismiss() }
                }
            }
            .alert("Togliere \(equipment.name)?", isPresented: $confirmDelete) {
                Button("Annulla", role: .cancel) {}
                Button("Togli", role: .destructive) {
                    equipment.gym = nil
                    context.delete(equipment)
                    try? context.save()
                    dismiss()
                }
            }
        }
        .presentationBackground(Theme.bg)
    }
}

/// Elenco di righe di testo modificabili, per muscoli, istruzioni e avvertenze.
struct ListEditor: View {
    @Binding var items: [String]
    let placeholder: String

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            TextField(placeholder, text: Binding(
                get: { items.indices.contains(index) ? items[index] : "" },
                set: { if items.indices.contains(index) { items[index] = $0 } }
            ), axis: .vertical)
        }
        .onDelete { items.remove(atOffsets: $0) }

        Button {
            items.append("")
        } label: {
            Label("Aggiungi", systemImage: "plus.circle.fill")
                .font(.subheadline)
        }
    }
}
