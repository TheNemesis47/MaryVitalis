import SwiftUI

struct RecapView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var profile: ProfileStore

    @State private var weekOffset = 0
    @State private var month = Date()
    @State private var pickedDay: String?
    @State private var confirmClear = false

    private var weekStart: Date { DateKey.adding(days: weekOffset * 7, to: DateKey.startOfWeek(Date())) }
    private var weekEnd: Date { DateKey.adding(days: 6, to: weekStart) }
    /// Lo storico arriva già filtrato sul profilo consultato: non si filtra più
    /// per identificativo di scheda, che con più schede a testa non funziona.
    private var history: [WorkoutSession] { store.history }
    private var sortedHistory: [WorkoutSession] { history.sorted { $0.dateKey < $1.dateKey } }
    private var accountName: String { profile.viewedAccount?.displayName ?? "—" }
    private var routines: [Routine] { profile.visibleRoutines }

    private var inWeek: [WorkoutSession] {
        history.filter { entry in
            let d = DateKey.date(from: entry.dateKey)
            return d >= weekStart && d <= weekEnd
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Statistiche", title: "Recap",
                           subtitle: history.isEmpty ? "Profilo di \(accountName)"
                           : "\(accountName): allenamenti svolti, carico settimanale e andamento dello sforzo percepito.")

                if history.isEmpty {
                    EmptyStateView(icon: "📊", title: "Ancora nessun allenamento",
                                   message: "Completa una scheda e segna lo sforzo: qui troverai calendario, statistiche e andamento.")
                } else {
                    weekPicker
                    weekStats
                    calendarBlock
                    effortBlock
                    perRoutineBlock
                    lastSessions
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .pageBackground()
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancellare tutto lo storico degli allenamenti?", isPresented: $confirmClear) {
            Button("Annulla", role: .cancel) {}
            Button("Cancella", role: .destructive) { store.clearHistory() }
        }
        .onChange(of: profile.viewedAccountID) { _, _ in
            weekOffset = 0
            pickedDay = nil
        }
    }

    private var weekPicker: some View {
        HStack(spacing: 10) {
            Button("←") { weekOffset -= 1 }
                .buttonStyle(GhostButtonStyle())
            VStack(spacing: 1) {
                Text("\(DateKey.short(weekStart)) – \(DateKey.short(weekEnd))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if weekOffset == 0 {
                    Text("questa settimana")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .frame(maxWidth: .infinity)
            Button("→") { weekOffset += 1 }
                .buttonStyle(GhostButtonStyle())
                .disabled(weekOffset >= 0)
                .opacity(weekOffset >= 0 ? 0.45 : 1)
        }
    }

    private var weekStats: some View {
        let sets = inWeek.reduce(0) { $0 + $1.setsDone }
        let duration = inWeek.reduce(0.0) { $0 + $1.duration }
        let sips = inWeek.reduce(0) { $0 + $1.sips }
        let efforts = inWeek.compactMap { $0.effort }.map(Double.init)
        let effort = Fmt.round1(Fmt.average(efforts))

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
            StatTile(value: "\(inWeek.count)", label: "Allenamenti")
            StatTile(value: "\(sets)", label: "Serie")
            StatTile(value: Fmt.duration(duration), label: "Tempo totale")
            StatTile(value: effort > 0 ? "\(effort)" : "—", label: "Sforzo medio")
            StatTile(value: "\(sips)", label: "Sorsi d'acqua")
        }
    }

    private var calendarBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            CalendarView(month: $month, selected: pickedDay,
                         onSelect: { iso in pickedDay = (iso == pickedDay ? nil : iso) },
                         marks: store.calendarMarks())

            // Una legenda per scheda: i pallini del calendario prendono il
            // colore della scheda, e ora le schede possono essere più di una.
            FlexibleTags(items: routines.map(\.name)) { name in
                let accent = routines.first { $0.name == name }?.accent ?? Theme.defaultAccent
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                    Text(name)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            if let pickedDay {
                let entries = history.filter { $0.dateKey == pickedDay }
                Panel {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateKey.long(DateKey.date(from: pickedDay)))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.text)
                        if entries.isEmpty {
                            Text("Nessun allenamento in questo giorno.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textDim)
                        } else {
                            ForEach(entries, id: \.id) { entry in
                                RecapLine(left: "\(entry.routineName) · giorno \(entry.dayIndex + 1)",
                                          right: "\(Fmt.duration(entry.duration)) · sforzo \(entry.effort.map(String.init) ?? "—")")
                            }
                        }
                    }
                }
            }
        }
    }

    private var effortBlock: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Andamento dello sforzo")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                EffortTrend(entries: sortedHistory)
            }
        }
    }

    private var perRoutineBlock: some View {
        Panel {
            VStack(alignment: .leading, spacing: 4) {
                Text("Per scheda")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(.bottom, 4)

                ForEach(routines, id: \.id) { routine in
                    RecapLine(left: "\(routine.emoji) \(routine.name)",
                              right: summary(for: routine),
                              leftColor: routine.accent)
                }
            }
        }
    }

    /// "3 sessioni · sforzo 6.3 · 58 min"
    private func summary(for routine: Routine) -> String {
        let list = history.filter { $0.routineID == routine.id }
        var text = Fmt.plural(list.count, "sessione", "sessioni")
        let efforts = list.compactMap { $0.effort }.map(Double.init)
        if !efforts.isEmpty { text += " · sforzo \(Fmt.round1(Fmt.average(efforts)))" }
        if !list.isEmpty { text += " · " + Fmt.duration(Fmt.average(list.map(\.duration))) }
        return text
    }

    private var lastSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Ultimi allenamenti", trailing: "Azzera storico") { confirmClear = true }
            Panel {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sortedHistory.suffix(12).reversed()), id: \.id) { entry in
                        RecapLine(
                            left: "\(entry.routineName) · \(entry.dayName)",
                            right: "\(DateKey.short(DateKey.date(from: entry.dateKey))) · \(Fmt.duration(entry.duration)) · \(entry.setsDone)/\(entry.sets) serie"
                                + (entry.effort.map { " · sforzo \($0)" } ?? ""),
                            leftColor: Color(hex: entry.accentHex)
                        )
                    }
                }
            }
        }
    }
}

/// Le ultime 10 sessioni con lo sforzo segnato, e il confronto fra recenti e precedenti.
struct EffortTrend: View {
    let entries: [WorkoutSession]

    private var scored: [WorkoutSession] {
        Array(entries.filter { $0.effort != nil }.suffix(10))
    }

    var body: some View {
        if scored.count < 2 {
            Text("Servono almeno due allenamenti con lo sforzo segnato.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        } else {
            let half = min(3, scored.count / 2)
            let recent = Fmt.average(scored.suffix(half).compactMap { $0.effort }.map(Double.init))
            let older = Fmt.average(scored.prefix(scored.count - half).compactMap { $0.effort }.map(Double.init))
            let diff = Fmt.round1(recent - older)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(scored, id: \.id) { entry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: entry.accentHex))
                            .frame(height: max(6, CGFloat(entry.effort ?? 0) / 10 * 90))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90, alignment: .bottom)

                HStack {
                    Text(DateKey.short(DateKey.date(from: scored.first!.dateKey)))
                    Spacer()
                    Text(DateKey.short(DateKey.date(from: scored.last!.dateKey)))
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)

                Text(deltaText(diff))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(deltaColor(diff))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(deltaColor(diff).opacity(0.12), in: Capsule())
            }
        }
    }

    private func deltaText(_ diff: Double) -> String {
        if diff <= -0.3 { return "↓ \(abs(diff)) — stesso lavoro, meno fatica" }
        if diff >= 0.3 { return "↑ \(diff) — sforzo in aumento" }
        return "stabile"
    }

    private func deltaColor(_ diff: Double) -> Color {
        if diff <= -0.3 { return Color(hex: "#4ade80") }
        if diff >= 0.3 { return Color(hex: "#fb7185") }
        return Theme.textDim
    }
}
