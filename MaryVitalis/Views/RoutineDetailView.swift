import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine

    @EnvironmentObject private var library: ExerciseLibrary
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = SessionController()

    @State private var activeDay = 0
    @State private var detail: ExerciseDetail?
    @State private var askDate = false
    @State private var askEffort = false
    @State private var showMap = false
    @State private var mapFocus: GymMachine?
    @State private var showEditor = false

    private var days: [RoutineDay] { routine.orderedDays }
    private var day: RoutineDay? { days.indices.contains(activeDay) ? days[activeDay] : nil }
    private var items: [RoutineItem] { day?.orderedItems ?? [] }
    private var stats: DayStats { store.stats(routine: routine, dayIndex: activeDay) }
    private var started: Bool { stats.setsDone > 0 }
    private var accent: Color { routine.accent }

    private func doneCount(_ item: RoutineItem) -> Int {
        guard let day else { return 0 }
        return store.doneCount(routineID: routine.id, dayID: day.id, itemID: item.id)
    }

    /// Indice dell'esercizio corrente: il primo non ancora completato.
    private var currentIndex: Int? {
        items.indices.first { doneCount(items[$0]) < items[$0].sets }
    }

    private var nextIndex: Int? {
        guard let current = currentIndex else { return nil }
        return items.indices.first { $0 > current && doneCount(items[$0]) < items[$0].sets }
    }

    /// Calcolata all'apertura della mappa e quando cambia una serie, non a
    /// ogni disegno: il cronometro ridisegna questa schermata quattro volte al
    /// secondo, e con lei tutto quello che le sta sopra — mappa compresa.
    @State private var mapHighlight: MapHighlight?

    private var highlight: MapHighlight {
        MapHighlight(
            current: currentIndex.map { mapItem(at: $0) },
            next: nextIndex.map { mapItem(at: $0) },
            completed: items.indices.compactMap { index in
                guard doneCount(items[index]) >= items[index].sets else { return nil }
                return mapItem(at: index)
            },
            accent: accent
        )
    }

    private func mapItem(at index: Int) -> MapHighlight.Item {
        let item = items[index]
        return MapHighlight.Item(
            title: exerciseName(at: index),
            detail: item.details,
            machines: profile.machines(for: item.exerciseQuery)
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    dayTabs
                    daySection
                    // Spazio per barra di sessione e pannelli fissi.
                    Color.clear.frame(height: session.isRunning ? 220 : 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }

            if session.isRunning {
                VStack(spacing: 10) {
                    if let rest = session.rest {
                        RestPanel(rest: rest, accent: accent,
                                  onAdd: { session.addRest($0) },
                                  onTogglePause: { session.toggleRestPause() },
                                  onStop: { session.stopRest() })
                    } else if session.showWaterPrompt {
                        WaterToast(suggested: WorkoutStore.sipsSuggested, accent: accent,
                                   onDrink: { session.addSips(WorkoutStore.sipsSuggested) },
                                   onDismiss: { session.dismissWaterPrompt() })
                    }

                    SessionBar(elapsed: session.elapsed, stats: stats, sips: session.sips,
                               sipsPulse: session.sipsPulse, accent: accent,
                               onSip: { session.addSips(1) },
                               onEnd: requestEnd)
                }
                .animation(.easeInOut(duration: 0.22), value: session.rest?.label)
                .animation(.easeInOut(duration: 0.22), value: session.showWaterPrompt)
            }
        }
        .pageBackground()
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mapFocus = nil
                    mapHighlight = highlight
                    showMap = true
                } label: {
                    Image(systemName: "map.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Modifica la scheda")
                // Durante l'allenamento la scheda non si tocca: cambiarla a
                // metà sposterebbe le serie sotto i piedi di chi la sta facendo.
                .disabled(session.isRunning)
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { RoutineEditorView(routine: routine) }
                .presentationBackground(Theme.bg)
        }
        .sheet(item: $detail) {
            ExerciseDetailView(detail: $0).environmentObject(profile)
        }
        .sheet(isPresented: $askDate) {
            DateSheet(initial: DateKey.iso(Date()), marks: store.calendarMarks(), accent: accent) { date in
                askDate = false
                guard let day else { return }
                session.start(
                    date: date,
                    routineID: routine.id,
                    dayID: day.id,
                    routineName: routine.name,
                    userName: routine.owner?.displayName ?? routine.name,
                    dayIndex: activeDay,
                    accentHex: routine.accentHex,
                    initialState: liveActivityState()
                )
            }
        }
        .sheet(isPresented: $askEffort) {
            EffortSheet(
                summary: .init(duration: session.elapsed, sets: stats.sets, setsDone: stats.setsDone,
                               sips: session.sips, date: session.date),
                accent: accent,
                onSave: saveSession,
                onDiscard: { askEffort = false; session.stop() }
            )
        }
        .sheet(isPresented: $showMap, onDismiss: { mapFocus = nil }) {
            NavigationStack {
                GymMapView(highlight: session.isRunning ? mapHighlight : nil,
                           focus: mapFocus,
                           showsDismissButton: true)
            }
            .presentationBackground(Theme.bg)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: activeDay) { _, _ in
            if !session.isRunning { session.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncWidgetCommands() }
        }
    }

    // MARK: - Sezioni

    private var hero: some View {
        Panel(padding: 18, radius: Theme.rXl) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(routine.emoji)
                        .font(.system(size: 26))
                        .frame(width: 52, height: 52)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.goal.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(accent)
                        Text("Scheda di \(routine.name)")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Theme.text)
                    }
                }
                Text(routine.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                FlexibleTags(items: routine.meta + ["\(routine.totalExercises) esercizi totali"]) {
                    MetaPill(text: $0)
                }
            }
        }
    }

    private var dayTabs: some View {
        HStack(spacing: 8) {
            ForEach(days.indices, id: \.self) { index in
                let s = store.stats(routine: routine, dayIndex: index)
                Button {
                    activeDay = index
                    Feedback.tap()
                } label: {
                    Chip(label: "Giorno \(index + 1)", active: index == activeDay,
                         done: s.isComplete, accent: accent)
                }
                .buttonStyle(.plain)
                .disabled(session.isRunning && index != activeDay)
                .opacity(session.isRunning && index != activeDay ? 0.4 : 1)
            }
            Spacer(minLength: 0)
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("\(activeDay + 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#0a0f1a"))
                    .frame(width: 28, height: 28)
                    .background(accent, in: Circle())
                Text(day?.name ?? "")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            // I contatori valgono per l'allenamento in corso, non per il giorno:
            // fuori dalla sessione il posto di quei numeri è il recap.
            if session.isRunning {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("**\(stats.exercisesDone)/\(stats.exercises)** esercizi · **\(stats.setsDone)/\(stats.sets)** serie")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textDim)
                        Spacer()
                        Text("\(stats.percent)%")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    ProgressTrack(percent: stats.percent, accent: accent)
                }
            } else {
                Text("\(stats.exercises) esercizi · \(stats.sets) serie in programma")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
            }

            if !session.isRunning {
                idleActions
            }

            if session.isRunning && stats.isComplete {
                Panel(padding: 18, radius: Theme.rLg) {
                    VStack(spacing: 8) {
                        Text("🎉").font(.system(size: 34))
                        Text("Allenamento completato!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("\(Fmt.clock(session.elapsed)) di lavoro · \(stats.sets) serie · \(session.sips) sorsi d'acqua")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textDim)
                        Button("Chiudi e segna lo sforzo", action: requestEnd)
                            .buttonStyle(PrimaryButtonStyle(accent: accent))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if session.isRunning {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        WorkoutRow(
                            item: item,
                            index: index + 1,
                            exercise: library.find(item.exerciseQuery),
                            doneCount: doneCount(item),
                            accent: accent,
                            onSet: { setDone(exercise: index, count: $0) },
                            onTimer: { seconds, label in session.startRest(seconds: seconds, label: label) },
                            onOpenDetail: {
                                if let ex = library.find(item.exerciseQuery) {
                                    detail = ExerciseDetail(exercise: ex, note: item.details)
                                }
                            },
                            onOpenMap: {
                                mapFocus = profile.machines(for: item.exerciseQuery).first
                                mapHighlight = highlight
                                showMap = true
                            }
                        )
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if let ex = library.find(item.exerciseQuery) {
                            ExerciseCard(exercise: ex, note: item.details, index: index + 1) {
                                detail = ExerciseDetail(exercise: ex, note: item.details)
                            }
                        }
                    }
                }
            }
        }
    }

    private var idleActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // "Riprendi" solo per un allenamento lasciato a metà: chiuderne
                // uno azzera il giorno da sé, quindi non serve nessun tasto per
                // farlo a mano.
                Button(started ? "▶ Riprendi la scheda" : "▶ Inizia la scheda") {
                    askDate = true
                }
                .buttonStyle(PrimaryButtonStyle(accent: accent))
                Spacer(minLength: 0)
            }

            if started {
                Text("Hai lasciato \(stats.setsDone) serie a metà: riprendendo riparti da lì.")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Text("Recupero")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
                ForEach(WorkoutStore.restOptions, id: \.self) { seconds in
                    Button { store.restDefault = seconds } label: {
                        Chip(label: "\(seconds)s", active: seconds == store.restDefault, accent: accent)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Azioni

    private func exerciseName(at index: Int) -> String {
        let item = items[index]
        return library.find(item.exerciseQuery)?.name ?? item.accentFallbackName
    }

    private func setDone(exercise index: Int, count: Int) {
        guard let day, items.indices.contains(index) else { return }
        let item = items[index]
        let increased = store.setDone(routineID: routine.id, dayID: day.id, item: item, count: count)
        Feedback.tap()
        session.updateWorkoutState(liveActivityState())
        // Se la mappa è aperta, "ORA" deve spostarsi sulla postazione giusta.
        if showMap { mapHighlight = highlight }

        // Serie appena completata: parte da sola la pausa di recupero.
        if increased, session.isRunning, !item.isCardio {
            session.startRest(seconds: item.restOverrideSeconds ?? store.restDefault, label: "Recupero")
        }
    }

    private func liveActivityState() -> WorkoutActivityAttributes.ContentState {
        let pending = items.indices.filter { doneCount(items[$0]) < items[$0].sets }

        guard let current = pending.first else {
            return WorkoutActivityAttributes.ContentState(
                exercise: .init(index: max(0, items.count - 1),
                                itemID: items.last?.id ?? UUID(),
                                name: "Allenamento completato",
                                details: day?.name ?? "",
                                completedSets: stats.sets,
                                totalSets: stats.sets,
                                isCardio: false),
                upcoming: [],
                exerciseNumber: items.count,
                totalExercises: items.count,
                selectedRestSeconds: store.restDefault,
                restEndsAt: nil,
                pausedRestSeconds: nil,
                isWorkoutComplete: true,
                updatedAt: Date()
            )
        }

        return WorkoutActivityAttributes.ContentState(
            exercise: liveExerciseSummary(at: current),
            upcoming: pending.dropFirst().map(liveExerciseSummary),
            exerciseNumber: current + 1,
            totalExercises: items.count,
            selectedRestSeconds: store.restDefault,
            restEndsAt: nil,
            pausedRestSeconds: nil,
            isWorkoutComplete: false,
            updatedAt: Date()
        )
    }

    private func liveExerciseSummary(at index: Int) -> WorkoutActivityAttributes.ExerciseSummary {
        let item = items[index]
        return .init(
            index: index,
            itemID: item.id,
            name: exerciseName(at: index),
            details: item.details,
            completedSets: doneCount(item),
            totalSets: item.sets,
            isCardio: item.isCardio
        )
    }

    private func syncWidgetCommands() {
        guard session.isRunning, let sessionID = session.sessionID, let day else { return }
        let commands = store.consumeWidgetCommands(sessionID: sessionID,
                                                   routineID: routine.id,
                                                   dayID: day.id)
        guard !commands.isEmpty else { return }
        session.refreshFromLiveActivity()
        session.updateWorkoutState(liveActivityState())
    }

    private func requestEnd() {
        session.stopRest()
        guard stats.setsDone > 0 else {
            session.stop()
            return
        }
        askEffort = true
    }

    private func saveSession(effort: Int) {
        if let day {
            store.addSession(
                routine: routine,
                day: day,
                dayIndex: activeDay,
                dateKey: session.date,
                duration: session.elapsed,
                stats: stats,
                sips: session.sips,
                effort: effort
            )
            // Le serie appartengono all'allenamento appena finito, non al
            // giorno della scheda: quello che resta è lo storico, e la
            // prossima volta si riparte puliti.
            store.resetDay(routineID: routine.id, dayID: day.id)
        }
        Feedback.success()
        askEffort = false
        session.stop()
    }
}
