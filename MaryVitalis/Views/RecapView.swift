import SwiftUI

struct RecapView: View {
    @EnvironmentObject private var store: WorkoutStore

    @State private var weekOffset = 0
    @State private var month = Date()
    @State private var pickedDay: String?
    @State private var confirmClear = false

    private var weekStart: Date { DateKey.adding(days: weekOffset * 7, to: DateKey.startOfWeek(Date())) }
    private var weekEnd: Date { DateKey.adding(days: 6, to: weekStart) }

    private var inWeek: [HistoryEntry] {
        store.history.filter { entry in
            let d = DateKey.date(from: entry.date)
            return d >= weekStart && d <= weekEnd
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Statistiche", title: "Recap",
                           subtitle: store.history.isEmpty ? nil
                           : "Allenamenti svolti, carico settimanale e andamento dello sforzo percepito.")

                if store.history.isEmpty {
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
                         marks: store.calendarMarks)

            HStack(spacing: 12) {
                ForEach(RoutineData.all) { routine in
                    HStack(spacing: 5) {
                        Circle().fill(routine.accent).frame(width: 7, height: 7)
                        Text(routine.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                Spacer(minLength: 0)
            }

            if let pickedDay {
                let entries = store.history.filter { $0.date == pickedDay }
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
                            ForEach(entries) { entry in
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
                EffortTrend(entries: store.sortedHistory)
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

                ForEach(RoutineData.all) { routine in
                    RecapLine(left: "\(routine.emoji) \(routine.name)",
                              right: summary(for: routine),
                              leftColor: routine.accent)
                }
            }
        }
    }

    /// "3 sessioni · sforzo 6.3 · 58 min"
    private func summary(for routine: Routine) -> String {
        let list = store.history.filter { $0.routineId == routine.id }
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
                    ForEach(store.sortedHistory.suffix(12).reversed()) { entry in
                        RecapLine(
                            left: "\(entry.routineName) · \(entry.dayName)",
                            right: "\(DateKey.short(DateKey.date(from: entry.date))) · \(Fmt.duration(entry.duration)) · \(entry.setsDone)/\(entry.sets) serie"
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
    let entries: [HistoryEntry]

    private var scored: [HistoryEntry] {
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
                    ForEach(scored) { entry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: entry.accentHex))
                            .frame(height: max(6, CGFloat(entry.effort ?? 0) / 10 * 90))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90, alignment: .bottom)

                HStack {
                    Text(DateKey.short(DateKey.date(from: scored.first!.date)))
                    Spacer()
                    Text(DateKey.short(DateKey.date(from: scored.last!.date)))
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
