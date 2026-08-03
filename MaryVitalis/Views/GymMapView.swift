import SwiftUI

/// Cosa evidenziare nell'elenco degli attrezzi mentre la scheda è in corso.
struct MapHighlight {
    struct Item {
        let title: String
        let detail: String
        let machines: [GymMachine]
    }

    let current: Item?
    let next: Item?
    let completed: [Item]
    let accent: Color

    var currentIDs: Set<String> { Set(current?.machines.map(\.id) ?? []) }
    var nextIDs: Set<String> { Set(next?.machines.map(\.id) ?? []) }
    var completedIDs: Set<String> { Set(completed.flatMap { $0.machines.map(\.id) }) }
}

/// La larghezza a disposizione della pianta, per decidere se le celle possono
/// allargarsi o se la sala deve scorrere di lato.
private struct PlanWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct EquipmentFloorRow: Identifiable {
    let id: String
    let machines: [GymMachine?]
    /// Le colonne che in questa riga sono passaggio.
    var walkways: Set<Int> = []
    let height: CGFloat

    /// Accesso a prova di riga costruita quando la sala aveva un'altra
    /// larghezza: fuori dai bordi si disegna una cella vuota, non si esce.
    func machine(at column: Int) -> GymMachine? {
        machines.indices.contains(column) ? machines[column] : nil
    }
}

/// Piantina verticale degli attrezzi della palestra.
///
/// Y determina la riga e X una delle quattro corsie. Le due coppie di corsie
/// sono separate dal corridoio centrale; gli spazi vuoti del rilievo restano
/// vuoti, quindi nessuna postazione viene ricompattata.
struct GymMapView: View {
    var highlight: MapHighlight? = nil
    var focus: GymMachine? = nil
    var showsDismissButton = false

    @AppStorage("mv:selected-gym") private var selectedGymID = ""
    @EnvironmentObject private var profile: ProfileStore
    @State private var showGyms = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selected: GymMachine?
    @State private var searchText = ""
    @State private var planWidth: CGFloat = 0

    /// Sotto questa larghezza una postazione non si legge più: da lì in poi la
    /// pianta scorre di lato invece di stringersi ancora.
    private let minimumCellWidth: CGFloat = 74
    private let aisleWidth: CGFloat = 44

    /// Le sedi già tradotte per il disegno, costruite **una volta**.
    ///
    /// Erano una proprietà calcolata, e `gym` pure: ogni lettura ricostruiva
    /// tutte le sedi e per ognuna riordinava gli attrezzi, confrontando
    /// `gridRow` e `gridColumn` — che sono letture vere dal database. Il corpo
    /// della vista le legge decine di volte, e `zone(for:)` una volta per
    /// attrezzo: con una sala da cinquanta postazioni erano migliaia di letture
    /// per un solo fotogramma, sul thread che disegna. Da lì gli otto secondi
    /// per aprire una schermata, i tocchi che arrivavano dopo, e le
    /// terminazioni durante il passaggio fra le schede.
    @State private var locations: [GymLocation] = []

    private var hasGyms: Bool { !locations.isEmpty }

    private var gym: GymLocation {
        locations.first { $0.id == selectedGymID } ?? locations.first ?? .none
    }

    /// Cambia quando cambia qualcosa che la mappa deve ridisegnare, e per
    /// saperlo non costruisce niente: legge un identificativo, una data e un
    /// conteggio.
    private var gymsSignature: String {
        (profile.viewedAccount?.gyms ?? [])
            .map { "\($0.id)-\($0.updatedAt.timeIntervalSince1970)-\($0.equipment?.count ?? 0)" }
            .sorted()
            .joined(separator: "|")
    }

    private func rebuildLocations() {
        var seen: Set<String> = []
        // Un elenco con due elementi dello stesso identificativo è un guaio per
        // chi lo disegna, e una sincronizzazione andata storta può lasciarne
        // due: qui si passa una volta sola.
        locations = (profile.viewedAccount?.gyms ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.asLocation)
            .filter { seen.insert($0.id).inserted }
    }

    private var accent: Color { highlight?.accent ?? Theme.defaultAccent }
    private let nextAccent = Color(hex: "#f59e0b")
    private let completedAccent = Color(hex: "#64748b")

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if !hasGyms {
                        noGymState
                    } else {
                        locationHeader

                        if let highlight, highlight.current != nil || highlight.next != nil {
                            highlightBanner(highlight)
                        }

                        gridHeader

                        if filteredMachines.isEmpty {
                            emptySearchState
                        } else {
                            floorPlan
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
                // La larghezza della pagina: dipende dallo schermo, non da
                // quello che ci si disegna dentro. È l'unico punto da cui si
                // può misurare senza innescare un anello.
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: PlanWidthKey.self, value: proxy.size.width)
                    }
                }
            }
            .onPreferenceChange(PlanWidthKey.self) { planWidth = $0 }
            .scrollDismissesKeyboard(.interactively)
            .task(id: scrollTargetRowID) {
                guard let rowID = scrollTargetRowID else { return }
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.easeInOut(duration: 0.28)) {
                    proxy.scrollTo(rowID, anchor: .center)
                }
            }
        }
        .pageBackground()
        .navigationTitle("Mappa")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: gymsSignature) { rebuildLocations() }
        .searchable(text: $searchText, prompt: "Attrezzo o gruppo muscolare")
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Label("Abbassa", systemImage: "chevron.down")
                    }
                    .accessibilityHint("Chiude la mappa e torna alla scheda")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showGyms = true } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Gestisci le sedi")
            }
        }
        .sheet(item: $selected) { machine in
            NavigationStack { MachineDetailView(machine: machine, gym: gym) }
                .presentationBackground(Theme.bg)
        }
        .onChange(of: selectedGymID) { _, _ in
            searchText = ""
            selected = nil
        }
        .sheet(isPresented: $showGyms) {
            GymListView().environmentObject(profile)
        }
    }

    // MARK: - Sede

    /// Cosa vede chi non ha ancora mappato niente. Non una palestra finta:
    /// l'invito a costruire la propria, che è l'unica che gli serve.
    private var noGymState: some View {
        VStack(spacing: 14) {
            EmptyStateView(icon: "🗺️", title: "Nessuna sede",
                           message: "Disegna la tua palestra: scegli quante righe e colonne ha la sala e riempi le celle con gli attrezzi che ci trovi.")
            Button("＋  Crea la tua sede") { showGyms = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private var locationHeader: some View {
        Menu {
            Picker("Palestra", selection: $selectedGymID) {
                ForEach(locations) { location in
                    Text(location.displayName).tag(location.id)
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            locationIcon
                            locationIdentity
                            Spacer(minLength: 8)
                            locationChevron
                        }
                        Text("\(gym.city) · \(gym.machines.count) attrezzi")
                            .font(.caption)
                            .foregroundStyle(Theme.textDim)
                    }
                } else {
                    HStack(spacing: 12) {
                        locationIcon
                        VStack(alignment: .leading, spacing: 2) {
                            locationIdentity
                            Text("\(gym.city) · \(gym.machines.count) attrezzi")
                                .font(.caption)
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer(minLength: 8)
                        locationChevron
                    }
                }
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Palestra selezionata: \(gym.displayName), \(gym.city)")
        .accessibilityHint("Cambia palestra")
    }

    private var locationIcon: some View {
        Image(systemName: "building.2.crop.circle.fill")
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(Theme.defaultAccent)
    }

    private var locationIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(gym.brand.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Theme.textFaint)
            Text(gym.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.text)
        }
    }

    private var locationChevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.textFaint)
    }

    private var gridHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Piantina della sala")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Vista dall’alto · tocca un attrezzo per i dettagli")
                    .font(.caption)
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text("\(filteredMachines.count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Theme.surfaceHi, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                .accessibilityLabel("\(filteredMachines.count) attrezzi visibili")
        }
    }

    // MARK: - Piantina

    /// La pianta sta in orizzontale quanto serve: con poche colonne riempie lo
    /// schermo, con tante le celle scendono alla larghezza minima e ci si
    /// sposta di lato invece di stringere tutto fino a non leggere più niente.
    /// La pianta si dimensiona da sé: le celle hanno una larghezza fissa, la
    /// riga è larga quanto le sue celle, e la ScrollView orizzontale scorre se
    /// non ci stanno.
    ///
    /// La larghezza disponibile **non** si misura qui. Misurarla su questa
    /// stessa vista, e poi usarla per decidere quanto è larga la pianta,
    /// chiudeva un anello: la misura cambiava la larghezza, la larghezza
    /// cambiava la misura. SwiftUI ci girava dentro finché il sistema non
    /// chiudeva l'app — a metà della transizione fra le schede, che è quando
    /// la mappa viene disegnata la prima volta.
    private var floorPlan: some View {
        ScrollView(.horizontal, showsIndicators: planColumns > 4) {
            LazyVStack(spacing: 0) {
                floorPlanHeader

                ForEach(Array(spatialFloorRows.enumerated()), id: \.element.id) { index, row in
                    floorRow(row, index: index)
                        .id(row.id)
                }
            }
            .padding(8)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background {
            FloorTexture()
                .background(Color(hex: "#101827"))
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .stroke(Theme.borderHi, lineWidth: 1.5)
        }
    }

    // MARK: - Misure della pianta

    private var planColumns: Int { max(1, gym.columns) }
    /// Le due metà della sala, con il corridoio in mezzo.
    private var leftColumns: Int { planColumns < 2 ? planColumns : planColumns / 2 }

    /// Il corridoio centrale fisso vale solo per chi non ha disegnato i propri.
    /// Era l'unico modo di rappresentare un passaggio, ed era per forza uno e
    /// verticale: chi ora se li mette dove passano davvero non lo vuole più fra
    /// i piedi.
    private var showsAisle: Bool { planColumns >= 2 && gym.walkways.isEmpty }

    private var planCellWidth: CGFloat {
        let gaps = 4 * CGFloat(max(0, planColumns - 2)) + (showsAisle ? 12 + aisleWidth : 0)
        let available = planWidth - 16 - gaps
        guard available > 0 else { return minimumCellWidth }
        return max(minimumCellWidth, available / CGFloat(planColumns))
    }


    @ViewBuilder
    private var floorPlanHeader: some View {
        if showsAisle {
            HStack(spacing: 6) {
                Text("LATO SINISTRO")
                    .frame(width: planCellWidth * CGFloat(leftColumns)
                           + 4 * CGFloat(max(0, leftColumns - 1)))

                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 9, weight: .bold))
                    Text("CORRIDOIO")
                        .font(.system(size: 6.5, weight: .black))
                        .tracking(0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Theme.textFaint)
                .frame(width: aisleWidth)

                Text("LATO DESTRO")
                    .frame(width: planCellWidth * CGFloat(planColumns - leftColumns)
                           + 4 * CGFloat(max(0, planColumns - leftColumns - 1)))
            }
            .font(.system(size: 8.5, weight: .bold))
            .tracking(0.65)
            .foregroundStyle(Theme.textFaint)
            .frame(height: 38)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            .accessibilityHidden(true)
        }
    }

    /// Una riga della sala. Il numero di colonne non è più quattro per legge:
    /// è quello della griglia disegnata nell'editor, e il corridoio cade a
    /// metà. Prima le posizioni oltre la quarta esistevano nei dati e non
    /// venivano disegnate: chi allargava la sala perdeva l'ultima corsia.
    private func floorRow(_ row: EquipmentFloorRow, index: Int) -> some View {
        let count = row.machines.count
        let split = count < 2 ? count : count / 2

        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<split, id: \.self) { column in
                    machineSlot(row.machine(at: column), column: column,
                                isWalkway: row.walkways.contains(column))
                        .frame(width: planCellWidth)
                }
            }

            if showsAisle {
                aisleSegment(index: index)
                    .frame(width: aisleWidth)
            }

            HStack(spacing: 4) {
                ForEach(split..<count, id: \.self) { column in
                    machineSlot(row.machine(at: column), column: column,
                                isWalkway: row.walkways.contains(column))
                        .frame(width: planCellWidth)
                }
            }
        }
        .frame(height: row.height)
    }

    private func aisleSegment(index: Int) -> some View {
        ZStack {
            Color(hex: "#0a1120").opacity(0.76)

            HStack {
                Rectangle().fill(Theme.borderHi).frame(width: 1)
                Spacer()
                Rectangle().fill(Theme.borderHi).frame(width: 1)
            }

            if index.isMultiple(of: 3) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textFaint.opacity(0.55))
            } else {
                Capsule()
                    .fill(Theme.textFaint.opacity(0.2))
                    .frame(width: 1.5, height: 18)
            }
        }
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func machineSlot(_ machine: GymMachine?, column: Int,
                             isWalkway: Bool = false) -> some View {
        if let machine {
            machineButton(machine, column: column)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
        } else if isWalkway {
            walkwayTile
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    /// Un pezzo di corridoio disegnato dall'utente. Stessa grafica del vecchio
    /// corridoio centrale, ma dove passa davvero — anche di traverso.
    private var walkwayTile: some View {
        ZStack {
            Color(hex: "#0a1120").opacity(0.76)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .accessibilityLabel("Passaggio")
    }

    private func machineButton(_ machine: GymMachine, column: Int) -> some View {
        let isCurrent = highlight?.currentIDs.contains(machine.id) ?? false
        let isNext = highlight?.nextIDs.contains(machine.id) ?? false
        let isCompleted = !isCurrent && !isNext && (highlight?.completedIDs.contains(machine.id) ?? false)
        let isHighlighted = isCurrent || isNext || isCompleted
        let stateColor = isCurrent ? accent : (isNext ? nextAccent : (isCompleted ? completedAccent : Theme.borderHi))
        let zone = gym.zone(for: machine)
        let iconTint = isHighlighted ? stateColor : Theme.textDim

        return Button {
            selected = machine
            Feedback.tap()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    EquipmentPlanSymbol(machine: machine, tint: iconTint)
                        .frame(width: 50, height: 50)

                        .shadow(color: Color.black.opacity(0.24), radius: 2, y: 2)

                    if isHighlighted {
                        Text(isCurrent ? "ORA" : (isNext ? "POI" : "FATTO"))
                            .font(.system(size: 7, weight: .black))
                            .tracking(0.4)
                            .foregroundStyle(isCompleted ? Theme.text : Color(hex: "#07101b"))
                            .padding(.horizontal, 4)
                            .frame(minHeight: 17)
                            .background(stateColor.opacity(isCompleted ? 0.72 : 1), in: Capsule())
                            .overlay(Capsule().stroke(stateColor.opacity(0.7), lineWidth: 1))
                            .offset(x: 10, y: -5)
                    }
                }

                Text(planLabel(for: machine))
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(isCompleted ? Theme.textDim : Theme.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .top)

                Text(compactMuscleSummary(for: machine))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                isHighlighted ? stateColor.opacity(isCurrent ? 0.14 : (isNext ? 0.11 : 0.07)) : .clear,
                in: RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .stroke(isHighlighted ? stateColor : .clear, lineWidth: isCurrent ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
        }
        .buttonStyle(EquipmentCardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: machine, zone: zone))
        .accessibilityHint("Apre gruppi muscolari, esercizi e istruzioni")
    }

    private var filteredMachines: [GymMachine] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return gym.machines.filter { machine in
                guard !normalizedQuery.isEmpty else { return true }
                let zoneName = gym.zone(for: machine)?.name ?? ""
                return ([machine.name, machine.subtitle ?? "", machine.category.rawValue, zoneName] + machine.muscles)
                    .joined(separator: " ")
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalizedQuery)
            }
    }

    private var scrollTargetRowID: String? {
        let machineID = focus?.id ?? highlight?.current?.machines.first?.id
        guard let machineID else { return nil }
        return spatialFloorRows.first { row in
            row.machines.contains { $0?.id == machineID }
        }?.id
    }

    /// La pianta, riga per riga, così com'è stata disegnata nell'editor.
    ///
    /// Prima la griglia veniva ricalcolata da coordinate continue e schiacciata
    /// su quattro corsie fisse: una sala larga sei attrezzi ci perdeva dentro
    /// quello che non ci stava. Ora riga e colonna sono un dato, non una stima.
    /// La griglia si costruisce sempre sull'intera sala: anche durante una
    /// ricerca gli attrezzi visibili non cambiano colonna.
    private var spatialFloorRows: [EquipmentFloorRow] {
        let visibleIDs = Set(filteredMachines.map(\.id))
        let byID = Dictionary(gym.machines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let rowCount = max(gym.rows,
                           (gym.placements.values.map(\.row).max() ?? -1) + 1,
                           (gym.walkways.map(\.row).max() ?? -1) + 1)

        var floorRows: [EquipmentFloorRow] = []
        for rowIndex in 0..<rowCount {
            let inRow = gym.placements.filter { $0.value.row == rowIndex }
            let walkwaysInRow = gym.walkways.filter { $0.row == rowIndex }
            // Una riga fatta solo di corridoio si disegna comunque: è quella
            // che fa capire dove si passa. Durante una ricerca invece si
            // mostrano solo le righe che contengono qualcosa di cercato.
            let hasVisibleMachine = inRow.contains { visibleIDs.contains($0.key) }
            let isSearching = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            guard hasVisibleMachine || (!isSearching && !walkwaysInRow.isEmpty) else { continue }

            let machines = (0..<gym.columns).map { column -> GymMachine? in
                guard let id = inRow.first(where: { $0.value.column == column })?.key,
                      visibleIDs.contains(id) else { return nil }
                return byID[id]
            }
            floorRows.append(EquipmentFloorRow(
                id: "\(gym.id)-r\(rowIndex)",
                machines: machines,
                walkways: Set(walkwaysInRow.map(\.column)),
                height: 112
            ))
        }
        return floorRows
    }

    private func compactMuscleSummary(for machine: GymMachine) -> String {
        guard let first = machine.muscles.first else { return "Da classificare" }
        let remaining = machine.muscles.count - 1
        return remaining > 0 ? "\(first) +\(remaining)" : first
    }

    private func planLabel(for machine: GymMachine) -> String {
        switch machine.id {
        case "colonna-multi-4": return "Stazione cavi ×4"
        case "colonna-multi-2": return "Stazione cavi ×2"
        case "cardio-non-identificato": return "Cardio ×3"
        case "area-corpo-libero": return "Panca inclinata"
        case "matrix-da-identificare": return "Matrix"
        case "hip-adductor-abductor": return "Adductor / Abductor"
        case "chest-incline-shoulder-press": return "Press 3 funzioni"
        case "panche": return "Panche regolabili ×6"
        default:
            return machine.name
                .replacingOccurrences(of: "Panca declinata regolabile", with: "Panca declinata")
                .replacingOccurrences(of: "Adjustable pulley", with: "Pulley")
                .replacingOccurrences(of: "Cardio salire scale", with: "Stair climber")
        }
    }

    private func accessibilityLabel(for machine: GymMachine, zone: GymZoneFrame?) -> String {
        var parts = [machine.name, machine.category.rawValue]
        if !machine.muscles.isEmpty {
            parts.append("Allena: \(machine.muscles.joined(separator: ", "))")
        }
        parts.append("Area: \(zone?.name ?? "Sala principale")")
        if highlight?.currentIDs.contains(machine.id) == true { parts.append("Esercizio attuale") }
        if highlight?.nextIDs.contains(machine.id) == true { parts.append("Esercizio successivo") }
        if highlight?.completedIDs.contains(machine.id) == true { parts.append("Esercizio completato") }
        return parts.joined(separator: ". ")
    }

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
            Text("Nessun attrezzo trovato")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("Prova con il nome dell’attrezzo, un’area o un gruppo muscolare.")
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Allenamento

    private func highlightBanner(_ highlight: MapHighlight) -> some View {
        HStack(spacing: 8) {
            if let current = highlight.current {
                banner(tag: "ORA", item: current, color: accent, filled: true)
            }
            if let next = highlight.next {
                banner(tag: "POI", item: next, color: nextAccent, filled: false)
            }
        }
    }

    private func banner(tag: String, item: MapHighlight.Item, color: Color, filled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tag)
                .font(.system(size: 9, weight: .black))
                .tracking(1)
                .foregroundStyle(filled ? Color(hex: "#07101b") : color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(filled ? color : color.opacity(0.14), in: Capsule())
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text(item.machines.first?.name ?? item.detail)
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMd).stroke(color.opacity(0.38), lineWidth: 1))
    }
}

private struct FloorTexture: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 22
            var path = Path()

            stride(from: tile, through: size.width, by: tile).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: tile, through: size.height, by: tile).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(Color.white.opacity(0.025)), lineWidth: 0.7)
        }
        .accessibilityHidden(true)
    }
}

private struct EquipmentCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
