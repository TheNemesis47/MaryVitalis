import SwiftUI

/// Le caselle delle serie. Si segnano **in ordine**: toccando la n-esima si
/// completano anche le precedenti, ritoccandone una già fatta si torna indietro.
struct SetPills: View {
    let plan: Plan
    let doneCount: Int
    let accent: Color
    var onSet: (Int) -> Void
    var onTimer: (Int, String) -> Void
    var cardioLabel: String

    var body: some View {
        if let minutes = plan.minutes {
            let complete = doneCount >= 1
            HStack(spacing: 8) {
                Button {
                    onSet(complete ? 0 : 1)
                } label: {
                    Text(complete ? "✓ Fatto" : "Segna fatto")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(complete ? Color(hex: "#0a0f1a") : Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(complete ? accent : Theme.surface, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(complete ? .clear : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    onTimer(minutes * 60, cardioLabel)
                } label: {
                    Text("▶ \(minutes) min")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 7) {
                ForEach(0..<plan.sets, id: \.self) { index in
                    let isDone = index < doneCount
                    Button {
                        // Toccando una casella non ancora fatta si completano anche le precedenti.
                        onSet(index + 1 > doneCount ? index + 1 : index)
                    } label: {
                        Text(isDone ? "✓" : "\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isDone ? Color(hex: "#0a0f1a") : Theme.textDim)
                            .frame(width: 38, height: 38)
                            .background(isDone ? accent : Theme.surface, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11)
                                .stroke(isDone ? .clear : (index == doneCount ? accent.opacity(0.55) : Theme.border), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Una riga della checklist in modalità allenamento.
struct WorkoutRow: View {
    let item: RoutineExercise
    let index: Int
    let exercise: Exercise?
    let doneCount: Int
    let accent: Color
    var onSet: (Int) -> Void
    var onTimer: (Int, String) -> Void
    var onOpenDetail: () -> Void
    var onOpenMap: () -> Void

    private var plan: Plan { item.plan }
    private var isComplete: Bool { doneCount >= plan.sets }
    private var name: String { exercise?.name ?? item.query }

    var body: some View {
        Panel(padding: 12, radius: Theme.rLg) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: onOpenDetail) {
                        ZStack(alignment: .topLeading) {
                            RemoteImage(url: exercise?.imageURL)
                                .frame(width: 64, height: 64)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("\(index)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#0a0f1a"))
                                .frame(width: 18, height: 18)
                                .background(accent, in: Circle())
                                .offset(x: -5, y: -5)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .top) {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isComplete ? Theme.textDim : Theme.text)
                                .strikethrough(isComplete, color: Theme.textFaint)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 6)
                            if doneCount > 0 {
                                Button { onSet(0) } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Theme.textFaint)
                                        .frame(width: 28, height: 28)
                                        .background(Theme.surfaceHi, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Azzera \(name)")
                            }
                        }
                        Text(item.details)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: onOpenMap) {
                            Label("Dove si fa", systemImage: "mappin.and.ellipse")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }

                SetPills(plan: plan, doneCount: doneCount, accent: accent,
                         onSet: onSet, onTimer: onTimer, cardioLabel: name)
            }
        }
        .opacity(isComplete ? 0.72 : 1)
    }
}

/// Pannello del recupero, fissato in basso sopra la barra di sessione.
struct RestPanel: View {
    let rest: RestTimerState
    let accent: Color
    var onAdd: (Double) -> Void
    var onTogglePause: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(rest.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(rest.isPaused ? "in pausa" : "in corso")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }

            Text(Fmt.clock(rest.left))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHi)
                    Capsule().fill(accent).frame(width: geo.size.width * rest.percent)
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {
                smallButton("−15s") { onAdd(-15) }
                smallButton(rest.isPaused ? "▶ Riprendi" : "⏸ Pausa", action: onTogglePause)
                smallButton("+15s") { onAdd(15) }
                Button("Salta", action: onStop)
                    .buttonStyle(PrimaryButtonStyle(accent: accent))
            }

            Text("Respira, sciogli le spalle e bevi un sorso d'acqua 💧")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.rXl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rXl, style: .continuous).stroke(accent.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func smallButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Promemoria idratazione: compare ogni 10 minuti durante la sessione.
struct WaterToast: View {
    let suggested: Int
    let accent: Color
    var onDrink: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("💧").font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bevi \(suggested) sorsi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Promemoria ogni 10 minuti")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textFaint)
            }
            Spacer(minLength: 6)
            Button("+\(suggested)", action: onDrink)
                .buttonStyle(PrimaryButtonStyle(accent: accent))
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Barra fissa con cronometro, serie, sorsi e il tasto di chiusura.
struct SessionBar: View {
    let elapsed: Double
    let stats: DayStats
    let sips: Int
    let sipsPulse: Int
    let accent: Color
    var onSip: () -> Void
    var onEnd: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            stat(Fmt.clock(elapsed), "Durata")
            stat("\(stats.setsDone)/\(stats.sets)", "Serie")
            stat("\(sips)", "Sorsi")
                .scaleEffect(pulse ? 1.22 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.5), value: pulse)

            Spacer(minLength: 0)

            Button(action: onSip) {
                Text("💧 +1")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button("Termina", action: onEnd)
                .buttonStyle(PrimaryButtonStyle(accent: accent))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
        .onChange(of: sipsPulse) { _, _ in
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulse = false }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textFaint)
        }
    }
}

/// "Quando lo stai facendo?" — si sceglie il giorno prima di partire.
struct DateSheet: View {
    @State private var selected: String
    @State private var month: Date
    let marks: [String: [String]]
    let accent: Color
    var onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    init(initial: String, marks: [String: [String]], accent: Color, onConfirm: @escaping (String) -> Void) {
        _selected = State(initialValue: initial)
        _month = State(initialValue: DateKey.date(from: initial))
        self.marks = marks
        self.accent = accent
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Quando lo stai facendo?")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Serve per il calendario e le statistiche settimanali.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textDim)

                    CalendarView(month: $month, selected: selected,
                                 onSelect: { selected = $0 }, marks: marks)

                    Text("Selezionato: **\(DateKey.long(DateKey.date(from: selected)))**")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 10) {
                        Button("Oggi") {
                            selected = DateKey.iso(Date())
                            month = Date()
                        }
                        .buttonStyle(GhostButtonStyle())

                        Button("Inizia ▶") { onConfirm(selected) }
                            .buttonStyle(PrimaryButtonStyle(accent: accent))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.bg)
    }
}

/// "Com'è andata?" — sforzo percepito e riepilogo, poi si salva nello storico.
struct EffortSheet: View {
    struct Summary {
        let duration: Double
        let sets: Int
        let setsDone: Int
        let sips: Int
        let date: String
    }

    let summary: Summary
    let accent: Color
    var onSave: (Int) -> Void
    var onDiscard: () -> Void

    @State private var effort: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Com'è andata?")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Segna lo sforzo percepito da 1 a 10: nel recap vedrai se cala a parità di lavoro.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textDim)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(1...10, id: \.self) { n in
                            Button { effort = n } label: {
                                Text("\(n)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(effort == n ? Color(hex: "#0a0f1a") : Theme.textDim)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(effort == n ? accent : Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(effort == n ? .clear : Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(effort.flatMap { Fmt.effortLabels[$0] } ?? " ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        RecapLine(left: "Durata", right: Fmt.duration(summary.duration))
                        RecapLine(left: "Serie completate", right: "\(summary.setsDone)/\(summary.sets)")
                        RecapLine(left: "Sorsi d'acqua", right: "\(summary.sips)")
                        RecapLine(left: "Giorno", right: DateKey.long(DateKey.date(from: summary.date)))
                    }

                    HStack(spacing: 10) {
                        Button("Non salvare", action: onDiscard)
                            .buttonStyle(GhostButtonStyle())
                        Button("Salva") { if let effort { onSave(effort) } }
                            .buttonStyle(PrimaryButtonStyle(accent: accent))
                            .frame(maxWidth: .infinity)
                            .disabled(effort == nil)
                            .opacity(effort == nil ? 0.5 : 1)
                    }
                    .padding(.top, 6)
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .presentationBackground(Theme.bg)
    }
}
