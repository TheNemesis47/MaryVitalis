import Foundation
import Combine
import SwiftUI

/// Recupero e blocchi cardio: countdown ancorato ai timestamp, così resta
/// preciso anche se il telefono sospende l'app.
struct RestTimerState {
    var total: Double
    var endsAt: Date
    var pausedLeft: Double?
    var label: String

    var isPaused: Bool { pausedLeft != nil }

    var left: Double {
        if let pausedLeft { return pausedLeft }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    var percent: Double {
        total > 0 ? max(0, min(1, left / total)) : 0
    }
}

/// Vive quanto il controller che lo possiede.
///
/// Se la pagina della scheda viene lasciata con l'allenamento ancora aperto —
/// si torna indietro, il sistema scarica la vista — nessuno chiama `stop()` e
/// la Live Activity resta accesa da sola per ore. Il `deinit` è l'unico posto
/// che se ne accorge.
private final class LiveActivityWatchdog {
    nonisolated(unsafe) var sessionID: String?

    deinit {
        guard let sessionID else { return }
        WorkoutActivityManager.end(sessionID: sessionID)
        RestAlarm.cancel()
    }
}

/// La modalità allenamento: cronometro, serie, recupero e promemoria acqua.
/// Tutto gira sul main thread: il ticker è un `Timer.publish(on: .main)`.
@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var isRunning = false
    /// Giorno scelto sul calendario (YYYY-MM-DD).
    @Published private(set) var date: String = DateKey.iso(Date())
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var sips = 0
    @Published var rest: RestTimerState?
    @Published var showWaterPrompt = false
    @Published private(set) var sessionID: String?
    /// Cambia a ogni sorso: serve solo a far ripartire l'animazione del contatore.
    @Published private(set) var sipsPulse = 0

    private var startedAt: Date?
    private var lastWaterReminder: Date?
    private var ticker: AnyCancellable?
    private let liveActivity = WorkoutActivityManager()
    private var liveState: WorkoutActivityAttributes.ContentState?
    private let watchdog = LiveActivityWatchdog()

    // MARK: - Ciclo di vita

    func start(date: String,
               routineID: UUID,
               dayID: UUID,
               routineName: String,
               userName: String,
               dayIndex: Int,
               accentHex: String,
               initialState: WorkoutActivityAttributes.ContentState) {
        let newSessionID = UUID().uuidString
        startedAt = Date()
        lastWaterReminder = Date()
        sessionID = newSessionID
        self.date = date
        elapsed = 0
        sips = 0
        rest = nil
        showWaterPrompt = false
        isRunning = true
        liveState = initialState
        watchdog.sessionID = newSessionID
        liveActivity.start(
            attributes: WorkoutActivityAttributes(
                sessionID: newSessionID,
                routineID: routineID,
                dayID: dayID,
                routineName: routineName,
                userName: userName,
                dayIndex: dayIndex,
                accentHex: accentHex,
                startedAt: startedAt ?? Date()
            ),
            state: initialState
        )
        Feedback.sessionStarted()
        // Il permesso serve prima che parta il primo recupero, non dopo.
        Task { await RestAlarm.requestAuthorizationIfNeeded() }
        startTicker()
    }

    func stop() {
        isRunning = false
        startedAt = nil
        rest = nil
        showWaterPrompt = false
        ticker?.cancel()
        ticker = nil
        RestAlarm.cancel()
        liveActivity.end(finalState: liveState)
        liveState = nil
        sessionID = nil
        watchdog.sessionID = nil
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isRunning, let startedAt else { return }
        // Il ticker batte quattro volte al secondo per tenere fluido il
        // recupero, ma i secondi trascorsi cambiano una volta al secondo:
        // pubblicarli comunque ridisegnava tutta la schermata quattro volte.
        let seconds = (Date().timeIntervalSince(startedAt)).rounded()
        if seconds != elapsed { elapsed = seconds }

        if let current = rest, !current.isPaused, current.left <= 0 {
            rest = nil
            clearLiveRest()
            // L'app è davanti: suona lei, e la sveglia di riserva si annulla.
            RestAlarm.cancel()
            Feedback.restFinished()
        }

        if let last = lastWaterReminder, Date().timeIntervalSince(last) >= WorkoutStore.waterInterval {
            lastWaterReminder = Date()
            showWaterPrompt = true
            Feedback.waterReminder()
        }
    }

    // MARK: - Recupero

    func startRest(seconds: Int, label: String) {
        rest = RestTimerState(total: Double(seconds),
                              endsAt: Date().addingTimeInterval(Double(seconds)),
                              pausedLeft: nil,
                              label: label)
        Feedback.restStarted()
        updateLiveRest()
        scheduleRestAlarm()
    }

    func addRest(_ seconds: Double) {
        guard var current = rest else { return }
        current.total = max(1, current.total + seconds)
        if let paused = current.pausedLeft {
            current.pausedLeft = max(0, paused + seconds)
        } else {
            current.endsAt = current.endsAt.addingTimeInterval(seconds)
        }
        rest = current
        updateLiveRest()
        scheduleRestAlarm()
    }

    func toggleRestPause() {
        guard var current = rest else { return }
        if let paused = current.pausedLeft {
            current.endsAt = Date().addingTimeInterval(paused)
            current.pausedLeft = nil
        } else {
            current.pausedLeft = max(0, current.endsAt.timeIntervalSinceNow)
        }
        rest = current
        updateLiveRest()
        scheduleRestAlarm()
    }

    func stopRest() {
        rest = nil
        clearLiveRest()
        RestAlarm.cancel()
    }

    /// Riallinea la sveglia allo stato attuale: in pausa non deve suonare.
    private func scheduleRestAlarm() {
        guard let rest, !rest.isPaused else {
            RestAlarm.cancel()
            return
        }
        RestAlarm.schedule(endsAt: rest.endsAt, label: rest.label)
    }

    // MARK: - Live Activity

    /// Aggiorna esercizio e serie conservando l'eventuale recupero già attivo.
    func updateWorkoutState(_ newState: WorkoutActivityAttributes.ContentState) {
        var next = newState
        if let current = liveState {
            next.selectedRestSeconds = current.selectedRestSeconds
            next.restEndsAt = current.restEndsAt
            next.pausedRestSeconds = current.pausedRestSeconds
        }
        next.updatedAt = Date()
        liveState = next
        liveActivity.update(next)
    }

    /// Allinea il timer locale allo stato modificato dai pulsanti della Lock Screen.
    func refreshFromLiveActivity() {
        liveActivity.refreshFromSystem()
        guard let current = liveActivity.state else { return }
        liveState = current

        if let endsAt = current.restEndsAt, endsAt > Date() {
            let remaining = endsAt.timeIntervalSinceNow
            rest = RestTimerState(total: max(Double(current.selectedRestSeconds), remaining),
                                  endsAt: endsAt,
                                  pausedLeft: nil,
                                  label: "Recupero")
        } else if let paused = current.pausedRestSeconds, paused > 0 {
            rest = RestTimerState(total: max(Double(current.selectedRestSeconds), Double(paused)),
                                  endsAt: Date().addingTimeInterval(Double(paused)),
                                  pausedLeft: Double(paused),
                                  label: "Recupero")
        } else {
            rest = nil
        }
        scheduleRestAlarm()
    }

    private func updateLiveRest() {
        guard var state = liveState, let rest else { return }
        state.restEndsAt = rest.isPaused ? nil : rest.endsAt
        state.pausedRestSeconds = rest.pausedLeft.map { max(0, Int($0.rounded(.up))) }
        state.updatedAt = Date()
        liveState = state
        liveActivity.update(state)
    }

    private func clearLiveRest() {
        guard var state = liveState else { return }
        state.restEndsAt = nil
        state.pausedRestSeconds = nil
        state.updatedAt = Date()
        liveState = state
        liveActivity.update(state)
    }

    // MARK: - Acqua

    func addSips(_ amount: Int) {
        sips += amount
        sipsPulse += 1
        showWaterPrompt = false
        Feedback.tap()
    }

    func dismissWaterPrompt() { showWaterPrompt = false }
}
