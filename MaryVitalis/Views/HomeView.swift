import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var library: ExerciseLibrary
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var profile: ProfileStore
    @State private var showSettings = false

    var openBodyPart: (String) -> Void
    var openRoutine: (UUID) -> Void
    var goToTab: (Tab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero
                stats
                routines
                bodyParts
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .pageBackground()
        .navigationTitle("Mary Vitalis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Impostazioni")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(profile)
                .environmentObject(store)
        }
    }

    private var hero: some View {
        Panel(padding: 20, radius: Theme.rXl) {
            VStack(alignment: .leading, spacing: 12) {
                Text("MARY VITALIS")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.textFaint)

                Label("Profilo di \(profile.viewedAccount?.displayName ?? "—")", systemImage: "person.crop.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: profile.viewedAccount?.accentHex ?? "#38bdf8"))

                (Text("Il tuo allenamento, ") + Text("spiegato bene.").italic().foregroundColor(Theme.defaultAccent))
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(Theme.text)

                Text("Oltre \(library.all.count) esercizi con animazione, muscoli coinvolti e istruzioni passo passo, più le schede personali e la mappa della palestra.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    Button("📋  Vai alle schede") { goToTab(.schede) }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        Button("🗺️  Mappa") { goToTab(.mappa) }
                            .buttonStyle(GhostButtonStyle())
                        Button("📊  Recap") { goToTab(.recap) }
                            .buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            StatTile(value: "\(library.all.count)", label: "Esercizi")
            StatTile(value: "\(library.targets.count)", label: "Gruppi muscolari")
            StatTile(value: "\(GymCatalog.defaultLocation.machines.count)", label: "Attrezzi mappati")
            StatTile(value: "\(profile.visibleRoutines.count)", label: "Schede accessibili")
        }
    }

    private var routines: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Le schede di allenamento", trailing: "Vedi tutte →") { goToTab(.schede) }
            ForEach(profile.visibleRoutines, id: \.id) { routine in
                RoutineCard(routine: routine, daysDone: store.completedDays(routine: routine)) {
                    openRoutine(routine.id)
                }
            }
        }
    }

    private var bodyParts: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Esplora per distretto", trailing: "Tutti →") { goToTab(.esercizi) }
            FlexibleTags(items: library.bodyParts) { part in
                Button {
                    openBodyPart(part)
                } label: {
                    MetaPill(text: "\(ExerciseLibrary.bodyPartIcons[part] ?? "•") \(Fmt.capitalizedFirst(part))")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Card della scheda, con l'accento personale come colore guida.
///
/// Senza `action` la card non contiene nessun bottone: è il caso in cui a
/// gestire il tocco è chi la ospita (un `NavigationLink`). Prima l'azione era
/// obbligatoria e chi non la voleva spegneva l'hit testing dell'intera card —
/// il che spegneva anche il tocco del link e il menu contestuale.
struct RoutineCard: View {
    let routine: Routine
    let daysDone: Int
    var action: (() -> Void)?

    var body: some View {
        Panel(padding: 18, radius: Theme.rXl) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(routine.emoji)
                        .font(.system(size: 24))
                        .frame(width: 48, height: 48)
                        .background(routine.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(routine.accent.opacity(0.35), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.goal.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(routine.accent)
                        Text(routine.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text)
                    }
                }

                Text(routine.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                FlexibleTags(items: routine.meta + (daysDone > 0 ? ["✓ \(daysDone)/\(routine.orderedDays.count) giorni"] : [])) { item in
                    MetaPill(text: item, color: item.hasPrefix("✓") ? routine.accent : Theme.textDim)
                }

                if let action {
                    Button("Apri la scheda →", action: action)
                        .buttonStyle(PrimaryButtonStyle(accent: routine.accent))
                        .frame(maxWidth: .infinity)
                } else {
                    openLabel
                }
            }
        }
    }

    /// Stessa forma del bottone, ma inerte: il tocco lo raccoglie il link.
    private var openLabel: some View {
        Text("Apri la scheda →")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(hex: "#0a0f1a"))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(routine.accent, in: Capsule())
    }
}

/// Wrap orizzontale per pillole di larghezza variabile.
struct FlexibleTags<Content: View>: View {
    let items: [String]
    @ViewBuilder var content: (String) -> Content

    var body: some View {
        // `LazyVGrid` adattivo: semplice, e va a capo da solo.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}
