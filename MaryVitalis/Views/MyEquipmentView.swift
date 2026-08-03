import SwiftUI

/// Gli attrezzi che hai, in un posto solo.
///
/// Non è un magazzino da riempire a mano in più: è quello che hai già messo
/// nelle tue sedi, visto per tipo invece che per esemplare — dieci tapis sono
/// un attrezzo, non dieci righe. Serve a due cose che prima non si vedevano
/// insieme: capire cosa hai, e sapere che è **questo** l'elenco che filtra i
/// milletrecento esercizi quando scrivi una scheda.
struct MyEquipmentView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var library: ExerciseLibrary

    @State private var search = ""
    @State private var showGyms = false

    private var entries: [ProfileStore.EquipmentEntry] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = profile.equipmentCatalog
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(query)
                || $0.sample.muscles.contains { $0.lowercased().contains(query) }
        }
    }

    /// Quanti dei milletrecento esercizi si possono fare con quello che c'è.
    private var doableCount: Int {
        library.all.filter(profile.availabilityFilter()).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(eyebrow: "ATTREZZI", title: "I miei attrezzi",
                           subtitle: "Quello che hai messo nelle tue sedi. È questo l'elenco che filtra gli esercizi quando scrivi una scheda.")

                if profile.equipmentCatalog.isEmpty {
                    EmptyStateView(icon: "🏋️", title: "Nessun attrezzo",
                                   message: "Mappa la tua palestra: gli attrezzi che ci metti finiscono qui, e da qui filtrano gli esercizi.")
                    Button("Vai alle sedi") { showGyms = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    summary

                    if profile.equipmentCatalog.count >= 8 { searchField }

                    ForEach(entries) { entry in
                        row(entry)
                    }

                    if entries.isEmpty {
                        Text("Nessun attrezzo con questo nome.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textFaint)
                    }

                    Button("＋  Aggiungine dalle sedi") { showGyms = true }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationTitle("Attrezzi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGyms) {
            GymListView().environmentObject(profile)
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(profile.equipmentCatalog.count)", label: "Tipi di attrezzo")
            StatTile(value: "\(profile.myEquipment.count)", label: "Postazioni")
            StatTile(value: "\(doableCount)", label: "Esercizi possibili")
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textFaint)
            TextField("Cerca un attrezzo", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.text)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }

    private func row(_ entry: ProfileStore.EquipmentEntry) -> some View {
        let color = entry.sample.machineCategory.color
        return Panel(padding: 13, radius: Theme.rLg) {
            HStack(spacing: 12) {
                EquipmentIconView(icon: entry.sample.icon, tint: color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(entry.gymNames.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                    if !entry.sample.muscles.isEmpty {
                        Text(entry.sample.muscles.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(color.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if entry.count > 1 {
                    Text("×\(entry.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 26)
                        .background(Theme.surfaceHi, in: Capsule())
                }
            }
        }
    }
}
