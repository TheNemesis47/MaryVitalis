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

    // MARK: - Ciclo di vita

    func start(date: String,
               routineID: String,
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
        liveActivity.start(
            attributes: WorkoutActivityAttributes(
                sessionID: newSessionID,
                routineID: routineID,
                routineName: routineName,
                userName: userName,
                dayIndex: dayIndex,
                accentHex: accentHex,
                startedAt: startedAt ?? Date()
            ),
            state: initialState
        )
        Feedback.sessionStarted()
        startTicker()
    }

    func stop() {
        isRunning = false
        startedAt = nil
        rest = nil
        showWaterPrompt = false
        ticker?.cancel()
        ticker = nil
        liveActivity.end(finalState: liveState)
        liveState = nil
        sessionID = nil
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isRunning, let startedAt else { return }
        elapsed = (Date().timeIntervalSince(startedAt)).rounded()

        if let current = rest, !current.isPaused, current.left <= 0 {
            rest = nil
            clearLiveRest()
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
        updateLiveRest()
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
    }

    func stopRest() {
        rest = nil
        clearLiveRest()
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
