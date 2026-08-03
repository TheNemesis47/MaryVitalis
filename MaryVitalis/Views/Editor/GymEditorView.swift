import SwiftData
import SwiftUI

/// Le palestre del profilo: creazione, scelta di quella attiva, modifica.
struct GymListView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("mv:selected-gym") private var selectedGymID = ""

    @State private var editing: Gym?
    /// Identificativo e nome, mai la sede: vedi `RoutinesView.PendingDeletion`.
    @State private var deleting: PendingDeletion?

    struct PendingDeletion: Identifiable {
        let id: UUID
        let name: String
    }
    @State private var sharing: Gym?
    @State private var assigning: Gym?
    @State private var showImport = false
    @State private var busy = false

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
                        Button("＋  Crea una sede") { createEmpty() }
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)

                        Button("↓  Importa con un codice") { showImport = true }
                            .buttonStyle(GhostButtonStyle())
                            .frame(maxWidth: .infinity)

                        Text("La sede nasce vuota: scegli quante righe e colonne ha la sala, poi riempi le celle pescando dai \(GymFactory.catalog.count) attrezzi che l'app conosce già — muscoli e istruzioni inclusi — o creandone di tuoi.")
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
        .sheet(isPresented: Binding(get: { sharing != nil },
                                    set: { if !$0 { sharing = nil } })) {
            if let sharing {
                ShareGymSheet(gym: sharing).environmentObject(profile)
            }
        }
        .sheet(isPresented: Binding(get: { assigning != nil },
                                    set: { if !$0 { assigning = nil } })) {
            if let assigning {
                AssignGymSheet(gym: assigning).environmentObject(profile)
            }
        }
        .sheet(isPresented: $showImport) {
            if let owner {
                ImportGymSheet(owner: owner).environmentObject(profile)
            }
        }
        .alert("Eliminare \(deleting?.name ?? "")?",
               isPresented: Binding(get: { deleting != nil },
                                    set: { if !$0 { deleting = nil } })) {
            Button("Annulla", role: .cancel) { deleting = nil }
            Button("Elimina", role: .destructive) {
                let target = deleting?.id
                deleting = nil
                if let target, let gym = gyms.first(where: { $0.id == target }) {
                    profile.delete(gym)
                }
                Feedback.tap()
            }
        } message: {
            Text("Sparisce anche dagli altri tuoi dispositivi. Le copie che hai condiviso o assegnato restano a chi le ha.")
        }
    }

    /// La riga della sede: scelta a sinistra, azioni a destra.
    ///
    /// Prima il tasto "modifica" era un bottone dentro il bottone della riga, e
    /// in SwiftUI quello esterno si prende tutti i tocchi: sembrava che il
    /// tasto non ci fosse. Eliminare stava solo nel menu contestuale, che nessuno
    /// trova. Ora sono due aree separate e il menu è visibile.
    private func gymRow(_ gym: Gym) -> some View {
        let active = selectedGymID == gym.id.uuidString
        return Panel(padding: 15, radius: Theme.rLg) {
            HStack(spacing: 13) {
                Button {
                    selectedGymID = gym.id.uuidString
                    Feedback.tap()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: active ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(active ? Theme.defaultAccent : Theme.textFaint)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(gym.displayName.isEmpty ? "Sede senza nome" : gym.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 6) {
                                Text("\(gym.city.isEmpty ? "" : gym.city + " · ")\(Fmt.plural(gym.orderedEquipment.count, "attrezzo", "attrezzi"))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textFaint)
                                if gym.isShared {
                                    Label(InviteCode.formatted(gym.shareCode), systemImage: "square.and.arrow.up")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color(hex: "#4ade80"))
                                }
                                if gym.sourceGymID != nil {
                                    Label("importata", systemImage: "arrow.down.circle")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Theme.textFaint)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    gymMenu(gym)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 40, height: 40)
                        .background(Theme.surfaceHi, in: Circle())
                }
                .accessibilityLabel("Azioni su \(gym.displayName)")
            }
        }
        .contextMenu { gymMenu(gym) }
    }

    @ViewBuilder
    private func gymMenu(_ gym: Gym) -> some View {
        Button { editing = gym } label: {
            Label("Modifica e rinomina", systemImage: "slider.horizontal.3")
        }
        if gym.owner?.id == profile.signedInAccountID {
            Button { sharing = gym } label: {
                Label(gym.isShared ? "Codice di condivisione" : "Condividi",
                      systemImage: "square.and.arrow.up")
            }
            if profile.account.map({ !profile.clients(of: $0).isEmpty }) == true {
                Button { assigning = gym } label: {
                    Label("Assegna a un cliente", systemImage: "person.2.fill")
                }
            }
        }
        Button(role: .destructive) {
            deleting = PendingDeletion(id: gym.id, name: gym.displayName)
        } label: {
            Label("Elimina", systemImage: "trash")
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
}

private struct GridWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Disposizione degli attrezzi sulla griglia della sala.
struct GymEditorView: View {
    @Bindable var gym: Gym

    @Environment(\.modelContext) private var context

    @State private var showPicker = false
    @State private var targetCell: (row: Int, column: Int)?
    @State private var editingEquipment: GymEquipment?
    @State private var removingWalkway: GymEquipment?
    @State private var removingEquipment: GymEquipment?
    @State private var dropTarget: Cell?
    @State private var gridWidth: CGFloat = 0

    private let minimumCellWidth: CGFloat = 78

    /// Una riga in più in fondo: c'è sempre dove appoggiare il prossimo attrezzo
    /// senza dover prima allargare la griglia.
    private var rows: Int { gym.gridRows }
    private var columns: Int { gym.gridColumns }

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

                Text("Tocca una cella vuota per metterci un attrezzo o un passaggio, toccane una piena per modificarla, e trascina per spostare: se nella cella di arrivo c'è già qualcosa, le due si scambiano di posto. Le celle vuote restano vuote: se in sala lì non c'è niente, la mappa lo rispecchia.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)

                sizeControls
                grid
            }
            .padding(18)
            // La larghezza si misura sulla pagina, non sulla griglia: misurare
            // quello di cui si decide la larghezza chiude un anello, e SwiftUI
            // ci gira dentro finché il sistema non chiude l'app.
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: GridWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .onPreferenceChange(GridWidthKey.self) { gridWidth = $0 }
        .pageBackground()
        .navigationTitle("Modifica sede")
        .navigationBarTitleDisplayMode(.inline)
        .onSettled([gym.name, gym.brand, gym.city]) { save() }
        .onDisappear { save() }
        .sheet(isPresented: $showPicker) {
            EquipmentPickerSheet(onPickWalkway: { addWalkway() }) { machine in
                addEquipment(from: machine)
            }
        }
        .alert("Togliere il passaggio?",
               isPresented: Binding(get: { removingWalkway != nil },
                                    set: { if !$0 { removingWalkway = nil } })) {
            Button("Annulla", role: .cancel) { removingWalkway = nil }
            Button("Togli", role: .destructive) {
                if let removingWalkway {
                    removingWalkway.gym = nil
                    context.delete(removingWalkway)
                    save()
                }
                removingWalkway = nil
            }
        } message: {
            Text("La cella torna vuota. Puoi rimetterci un attrezzo o un altro passaggio.")
        }
        .sheet(isPresented: Binding(get: { editingEquipment != nil },
                                    set: { if !$0 { editingEquipment = nil } }),
               onDismiss: removePendingEquipment) {
            if let editingEquipment {
                EquipmentEditorSheet(equipment: editingEquipment, gym: gym) { item in
                    removingEquipment = item
                }
            }
        }
    }

    /// Quanto è grande la sala. Una palestra lunga e stretta e una larga e corta
    /// non si mappano con la stessa griglia, quindi si dimensiona a mano.
    private var sizeControls: some View {
        Panel(padding: 14, radius: Theme.rLg) {
            VStack(spacing: 12) {
                sizeStepper(title: "Colonne", value: columns,
                            canRemove: columns > 1 && gym.gridColumns > lastUsedColumn + 1,
                            onAdd: { gym.columns = columns + 1; save() },
                            onRemove: { gym.columns = max(1, columns - 1); save() })

                Rectangle().fill(Theme.border).frame(height: 1)

                sizeStepper(title: "Righe", value: rows,
                            canRemove: rows > 1 && gym.gridRows > lastUsedRow + 1,
                            onAdd: { gym.rows = rows + 1; save() },
                            onRemove: { gym.rows = max(1, rows - 1); save() })

                Text(lastUsedRow + 1 >= rows || lastUsedColumn + 1 >= columns
                     ? "Per restringere, togli prima gli attrezzi dall'ultima riga o colonna."
                     : "Aggiungi righe se la sala è profonda, colonne se è larga.")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lastUsedRow: Int { gym.rowCount - 1 }
    private var lastUsedColumn: Int { (gym.orderedEquipment.map(\.gridColumn).max() ?? -1) }

    private func sizeStepper(title: String, value: Int, canRemove: Bool,
                             onAdd: @escaping () -> Void,
                             onRemove: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            HStack(spacing: 14) {
                stepButton("minus", enabled: canRemove) { onRemove(); Feedback.tap() }
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .frame(minWidth: 28)
                stepButton("plus", enabled: value < 12) { onAdd(); Feedback.tap() }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func stepButton(_ symbol: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.text : Theme.textFaint.opacity(0.4))
                .frame(width: 38, height: 38)
                .background(Theme.surfaceHi, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func save() {
        gym.updatedAt = .now
        try? context.save()
    }

    /// Come la mappa: finché ci stanno, le celle riempiono la larghezza; oltre,
    /// restano leggibili e la griglia scorre di lato.
    private var grid: some View {
        // La mappa cella→attrezzo si costruisce una volta per disegno. Prima
        // ogni cella chiedeva `equipment(atRow:column:)`, che riordina l'intera
        // sala a ogni chiamata: con cento celle e cinquanta attrezzi erano
        // cento riordinamenti per fotogramma, sul thread che disegna.
        let placed = Dictionary(
            gym.orderedEquipment.map { (Cell(row: $0.gridRow, column: $0.gridColumn), $0) },
            uniquingKeysWith: { current, _ in current }
        )

        return ScrollView(.horizontal, showsIndicators: columns > 4) {
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<columns, id: \.self) { column in
                            cell(row: row, column: column,
                                 item: placed[Cell(row: row, column: column)])
                                .frame(width: cellWidth)
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private var cellWidth: CGFloat {
        let gaps = 8 * CGFloat(max(0, columns - 1))
        let available = gridWidth - gaps
        guard available > 0 else { return minimumCellWidth }
        return max(minimumCellWidth, available / CGFloat(columns))
    }

    private struct Cell: Hashable {
        let row: Int
        let column: Int
    }

    private func cell(row: Int, column: Int, item: GymEquipment?) -> some View {
        Button {
            if let item {
                if item.isWalkway {
                    removingWalkway = item
                } else {
                    editingEquipment = item
                }
            } else {
                targetCell = (row, column)
                showPicker = true
            }
            Feedback.tap()
        } label: {
            cellContent(item)
        }
        .buttonStyle(.plain)
        // Trascinare è il modo naturale di spostare una postazione: prima
        // bisognava aprirla e cambiare due contatori "riga" e "colonna",
        // che è il contrario di guardare una piantina.
        .draggable(item?.id.uuidString ?? "") {
            cellContent(item).frame(width: cellWidth).opacity(0.9)
        }
        .dropDestination(for: String.self) { payload, _ in
            move(payload.first, toRow: row, column: column)
        } isTargeted: { targeted in
            dropTarget = targeted ? Cell(row: row, column: column) : nil
        }
        .overlay {
            if dropTarget == Cell(row: row, column: column) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.defaultAccent, lineWidth: 2)
            }
        }
        .accessibilityLabel(accessibilityLabel(item, row: row, column: column))
    }

    @ViewBuilder
    private func cellContent(_ item: GymEquipment?) -> some View {
        if let item, item.isWalkway {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, minHeight: 76)
                .background(Color(hex: "#0a1120").opacity(0.75),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.borderHi, lineWidth: 1))
        } else if let item {
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

    private func accessibilityLabel(_ item: GymEquipment?, row: Int, column: Int) -> String {
        guard let item else { return "Cella vuota, riga \(row + 1) colonna \(column + 1)" }
        return item.isWalkway ? "Passaggio, riga \(row + 1) colonna \(column + 1)" : item.name
    }

    /// Sposta una postazione nella cella indicata. Se lì c'è già qualcosa le
    /// due si scambiano di posto: nella sala reale gli attrezzi si spostano,
    /// non si sovrascrivono.
    @discardableResult
    private func move(_ payload: String?, toRow row: Int, column: Int) -> Bool {
        guard let payload, let id = UUID(uuidString: payload),
              let moved = gym.orderedEquipment.first(where: { $0.id == id }),
              moved.gridRow != row || moved.gridColumn != column else { return false }

        let origin = (row: moved.gridRow, column: moved.gridColumn)
        if let occupant = gym.orderedEquipment.first(where: {
            $0.gridRow == row && $0.gridColumn == column
        }) {
            occupant.gridRow = origin.row
            occupant.gridColumn = origin.column
        }
        moved.gridRow = row
        moved.gridColumn = column
        save()
        Feedback.success()
        return true
    }

    private func removePendingEquipment() {
        guard let removingEquipment else { return }
        removingEquipment.gym = nil
        context.delete(removingEquipment)
        save()
        self.removingEquipment = nil
        Feedback.tap()
    }

    /// Un pezzo di corridoio. Occupa una cella come un attrezzo, così può
    /// andare anche di traverso: una sala ha i passaggi che ha, non uno solo
    /// verticale in mezzo.
    private func addWalkway() {
        let cell = targetCell ?? gym.firstFreeCell
        let walkway = GymEquipment(name: "Passaggio", category: .altro,
                                   gridRow: cell.row, gridColumn: cell.column,
                                   kind: .walkway)
        walkway.gym = gym
        context.insert(walkway)
        save()
        targetCell = nil
        Feedback.success()
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
    var onPickWalkway: () -> Void = {}
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

                    Button {
                        onPickWalkway()
                        dismiss()
                    } label: {
                        Label("Passaggio", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }
                    .listRowBackground(Theme.surface)
                } footer: {
                    Text("Se in sala hai qualcosa che non è in elenco, aggiungilo tu con nome, muscoli e istruzioni. Il passaggio serve a disegnare i corridoi — anche di traverso.")
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
    /// Chiede a chi ha aperto il foglio di togliere l'attrezzo, a chiusura
    /// avvenuta. Vedi il commento sull'avviso qui sotto.
    var onRemove: (GymEquipment) -> Void = { _ in }

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
                    Stepper("Riga \(equipment.gridRow + 1)",
                            value: $equipment.gridRow, in: 0...max(0, gym.gridRows - 1))
                    Stepper("Colonna \(equipment.gridColumn + 1)",
                            value: $equipment.gridColumn, in: 0...max(0, gym.gridColumns - 1))
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
                    Button("Fine") {
                        // Anche la sede risulta cambiata: è la sua data che
                        // dice alla mappa che deve rifare i conti.
                        gym.updatedAt = .now
                        try? context.save()
                        dismiss()
                    }
                }
            }
            // La cancellazione la esegue chi ha aperto il foglio, dopo che il
            // foglio si è chiuso: cancellare qui vorrebbe dire distruggere
            // l'attrezzo mentre questa stessa schermata ne sta leggendo il nome
            // per scrivere il titolo, e toccare un modello distrutto termina
            // il processo.
            .alert("Togliere \(equipment.name)?", isPresented: $confirmDelete) {
                Button("Annulla", role: .cancel) {}
                Button("Togli", role: .destructive) {
                    onRemove(equipment)
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

/// Il codice con cui altri importano questa sede.
struct ShareGymSheet: View {
    let gym: Gym

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var busy = false
    @State private var copied = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "CONDIVIDI", title: gym.displayName,
                               subtitle: "Chi ha questo codice può importare la tua sede con tutti gli attrezzi che hai mappato.")

                    if code.isEmpty {
                        Button {
                            Task { await share() }
                        } label: {
                            if busy {
                                ProgressView().frame(maxWidth: .infinity, minHeight: 22)
                            } else {
                                Text("Genera il codice").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy)
                    } else {
                        Panel(padding: 18, radius: Theme.rLg) {
                            HStack {
                                Text(InviteCode.formatted(code))
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .tracking(2)
                                    .foregroundStyle(Theme.defaultAccent)
                                    .textSelection(.enabled)
                                Spacer(minLength: 8)
                                Button {
                                    UIPasteboard.general.string = code
                                    copied = true
                                    Feedback.tap()
                                } label: {
                                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.title3)
                                        .foregroundStyle(copied ? Color(hex: "#4ade80") : Theme.textDim)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Chi lo usa riceve una **copia**: la adatta come vuole e la tua sede resta com'è. Se in futuro la migliori, ricondividi il codice.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Smetti di condividere") {
                            Task { await stop() }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)

                        Text("Il codice smette di funzionare. Le copie già fatte restano a chi le ha: sono sue, non un prestito.")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
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
        .onAppear { code = gym.isShared ? gym.shareCode : "" }
    }

    private func share() async {
        busy = true
        errorMessage = nil
        do { code = try await profile.shareGym(gym); Feedback.success() }
        catch { errorMessage = error.localizedDescription }
        busy = false
    }

    private func stop() async {
        do { try await profile.stopSharing(gym); code = ""; Feedback.tap() }
        catch { errorMessage = error.localizedDescription }
    }
}

/// Importazione della sede di qualcun altro tramite codice.
struct ImportGymSheet: View {
    let owner: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var normalized: String { InviteCode.normalize(code) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "IMPORTA", title: "Codice della sede",
                               subtitle: "Fattelo dare da chi ha già mappato la palestra: te la ritrovi pronta, con attrezzi e istruzioni.")

                    TextField("K7M-2QX", text: $code)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.go)
                        .onSubmit { Task { await importGym() } }
                        .padding(.vertical, 16)
                        .background(Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                            .stroke(errorMessage == nil ? Theme.border : Color(hex: "#fb7185"), lineWidth: 1))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await importGym() }
                    } label: {
                        if busy {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 22)
                        } else {
                            Text("Importa").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy || !InviteCode.isValid(normalized))
                    .opacity(InviteCode.isValid(normalized) && !busy ? 1 : 0.5)

                    Text("Ne ricevi una copia tua: puoi spostare, togliere o aggiungere attrezzi senza toccare la sede di chi te l'ha data.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Ti alleni da \(GymBirreria.brand) \(GymBirreria.name)?") {
                        code = GymBirreria.code
                        Task { await importGym() }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.defaultAccent)
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
        }
        .presentationBackground(Theme.bg)
        .onAppear { focused = true }
    }

    private func importGym() async {
        busy = true
        errorMessage = nil
        do {
            try await profile.importGym(code: normalized, for: owner)
            Feedback.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }
}

/// Assegnazione di una sede a un cliente seguito.
struct AssignGymSheet: View {
    let gym: Gym

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var assigned: Set<UUID> = []
    @State private var busy = false
    @State private var errorMessage: String?

    private var clients: [UserAccount] {
        profile.account.map { profile.clients(of: $0) } ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PageHeader(eyebrow: "ASSEGNA", title: gym.displayName,
                               subtitle: "Ne mandi una copia al cliente: la troverà fra le sue sedi, e potrà adattarla.")

                    ForEach(clients, id: \.id) { client in
                        clientRow(client)
                    }

                    if clients.isEmpty {
                        EmptyStateView(icon: "👥", title: "Nessun cliente",
                                       message: "Collega prima qualcuno con il codice, dalle impostazioni.")
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
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
    }

    private func clientRow(_ client: UserAccount) -> some View {
        let done = assigned.contains(client.id)
        return Button {
            Task { await assign(to: client) }
        } label: {
            Panel(padding: 14, radius: Theme.rLg) {
                HStack(spacing: 12) {
                    Image(systemName: done ? "checkmark.circle.fill" : client.symbolName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(done ? Color(hex: "#4ade80") : Color(hex: client.accentHex))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: client.accentHex).opacity(0.12), in: Circle())
                    Text(client.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 8)
                    if done {
                        Text("assegnata")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: "#4ade80"))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(busy || done)
    }

    private func assign(to client: UserAccount) async {
        busy = true
        errorMessage = nil
        do {
            try await profile.assignGym(gym, to: client)
            assigned.insert(client.id)
            Feedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
        busy = false
    }
}
