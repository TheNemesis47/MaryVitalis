import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine

    @EnvironmentObject private var library: ExerciseLibrary
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = SessionController()

    @State private var activeDay = 0
    @State private var detail: ExerciseDetail?
    @State private var askDate = false
    @State private var askEffort = false
    @State private var showMap = false
    @State private var mapFocus: GymMachine?

    private var day: RoutineDay { routine.days[activeDay] }
    private var stats: DayStats { store.stats(routine: routine, day: activeDay) }
    private var started: Bool { stats.setsDone > 0 }
    private var accent: Color { routine.accent }

    /// Indice dell'esercizio corrente: il primo non ancora completato.
    private var currentIndex: Int? {
        day.exercises.indices.first { index in
            store.doneCount(routineId: routine.id, day: activeDay, exercise: index) < day.exercises[index].plan.sets
        }
    }

    private var nextIndex: Int? {
        guard let current = currentIndex else { return nil }
        return day.exercises.indices.first { index in
            index > current && store.doneCount(routineId: routine.id, day: activeDay, exercise: index) < day.exercises[index].plan.sets
        }
    }

    private var highlight: MapHighlight {
        MapHighlight(
            current: currentIndex.map { MapHighlight.Item(
                title: exerciseName(at: $0),
                detail: day.exercises[$0].details,
                machines: GymCatalog.machines(for: day.exercises[$0].query)
            ) },
            next: nextIndex.map { MapHighlight.Item(
                title: exerciseName(at: $0),
                detail: day.exercises[$0].details,
                machines: GymCatalog.machines(for: day.exercises[$0].query)
            ) },
            completed: day.exercises.indices.compactMap { index in
                let item = day.exercises[index]
                guard store.doneCount(routineId: routine.id, day: activeDay, exercise: index) >= item.plan.sets else {
                    return nil
                }
                return MapHighlight.Item(
                    title: exerciseName(at: index),
                    detail: item.details,
                    machines: GymCatalog.machines(for: item.query)
                )
            },
            accent: accent
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
                    showMap = true
                } label: {
                    Image(systemName: "map.fill")
                }
            }
        }
        .sheet(item: $detail) { ExerciseDetailView(detail: $0) }
        .sheet(isPresented: $askDate) {
            DateSheet(initial: DateKey.iso(Date()), marks: store.calendarMarks(userID: routine.id), accent: accent) { date in
                askDate = false
                session.start(
                    date: date,
                    routineID: routine.id,
                    routineName: routine.name,
                    userName: routine.name,
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
                GymMapView(highlight: session.isRunning ? highlight : nil,
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
            ForEach(routine.days.indices, id: \.self) { index in
                let s = store.stats(routine: routine, day: index)
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
                Text(day.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

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
                    ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                        WorkoutRow(
                            item: item,
                            index: index + 1,
                            exercise: library.find(item.query),
                            doneCount: store.doneCount(routineId: routine.id, day: activeDay, exercise: index),
                            accent: accent,
                            onSet: { setDone(exercise: index, count: $0) },
                            onTimer: { seconds, label in session.startRest(seconds: seconds, label: label) },
                            onOpenDetail: {
                                if let ex = library.find(item.query) {
                                    detail = ExerciseDetail(exercise: ex, note: item.details)
                                }
                            },
                            onOpenMap: {
                                mapFocus = GymCatalog.machines(for: item.query).first
                                showMap = true
                            }
                        )
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                    ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                        if let ex = library.find(item.query) {
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
                Button(started && !stats.isComplete ? "▶ Riprendi la scheda" : "▶ Inizia la scheda") {
                    askDate = true
                }
                .buttonStyle(PrimaryButtonStyle(accent: accent))

                if started {
                    Button("↺ Azzera") {
                        store.resetDay(routineId: routine.id, day: activeDay)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Spacer(minLength: 0)
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
        let item = day.exercises[index]
        return library.find(item.query)?.name ?? item.query
    }

    private func setDone(exercise index: Int, count: Int) {
        let plan = day.exercises[index].plan
        let increased = store.setDone(routineId: routine.id, day: activeDay,
                                      exercise: index, count: count, maxSets: plan.sets)
        Feedback.tap()
        session.updateWorkoutState(liveActivityState())

        // Serie appena completata: parte da sola la pausa di recupero.
        if increased, session.isRunning, !plan.isCardio {
            session.startRest(seconds: store.restDefault, label: "Recupero")
        }
    }

    private func liveActivityState() -> WorkoutActivityAttributes.ContentState {
        let pending = day.exercises.indices.filter { index in
            store.doneCount(routineId: routine.id, day: activeDay, exercise: index) < day.exercises[index].plan.sets
        }

        guard let current = pending.first else {
            return WorkoutActivityAttributes.ContentState(
                exercise: .init(index: max(0, day.exercises.count - 1),
                                name: "Allenamento completato",
                                details: day.name,
                                completedSets: stats.sets,
                                totalSets: stats.sets),
                upcoming: [],
                exerciseNumber: day.exercises.count,
                totalExercises: day.exercises.count,
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
            totalExercises: day.exercises.count,
            selectedRestSeconds: store.restDefault,
            restEndsAt: nil,
            pausedRestSeconds: nil,
            isWorkoutComplete: false,
            updatedAt: Date()
        )
    }

    private func liveExerciseSummary(at index: Int) -> WorkoutActivityAttributes.ExerciseSummary {
        let item = day.exercises[index]
        return .init(
            index: index,
            name: exerciseName(at: index),
            details: item.details,
            completedSets: store.doneCount(routineId: routine.id, day: activeDay, exercise: index),
            totalSets: item.plan.sets
        )
    }

    private func syncWidgetCommands() {
        guard session.isRunning, let sessionID = session.sessionID else { return }
        let commands = store.consumeWidgetCommands(sessionID: sessionID,
                                                   routineID: routine.id,
                                                   dayIndex: activeDay)
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
        store.addHistory(HistoryEntry(
            id: UUID().uuidString,
            routineId: routine.id,
            routineName: routine.name,
            accentHex: routine.accentHex,
            dayIndex: activeDay,
            dayName: day.name,
            date: session.date,
            duration: session.elapsed,
            sets: stats.sets,
            setsDone: stats.setsDone,
            sips: session.sips,
            effort: effort
        ))
        Feedback.success()
        askEffort = false
        session.stop()
    }
}
