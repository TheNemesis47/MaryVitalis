import ActivityKit
import Foundation

@MainActor
final class WorkoutActivityManager {
    private(set) var activity: Activity<WorkoutActivityAttributes>?
    private(set) var state: WorkoutActivityAttributes.ContentState?

    /// Oltre questo l'allenamento non è più "in corso", è dimenticato: senza un
    /// orizzonte il sistema terrebbe l'attività viva per ore.
    private static let maximumDuration: TimeInterval = 4 * 3_600

    func start(attributes: WorkoutActivityAttributes,
               state initialState: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        for existing in Activity<WorkoutActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }

        do {
            let content = ActivityContent(state: initialState,
                                          staleDate: Date().addingTimeInterval(Self.maximumDuration),
                                          relevanceScore: 1)
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            state = initialState
        } catch {
            // L'allenamento nell'app continua anche se le Live Activity sono disattivate.
            activity = nil
            state = nil
        }
    }

    func update(_ newState: WorkoutActivityAttributes.ContentState) {
        state = newState
        guard let activity else { return }
        // Fuori dal recupero la scadenza resta quella dell'allenamento: prima
        // era `nil`, e un'attività senza scadenza non diventa mai obsoleta.
        let staleDate = newState.restEndsAt
            ?? activity.attributes.startedAt.addingTimeInterval(Self.maximumDuration)
        Task {
            await activity.update(ActivityContent(state: newState, staleDate: staleDate, relevanceScore: 1))
        }
    }

    func refreshFromSystem() {
        guard let id = activity?.id,
              let current = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else {
            return
        }
        activity = current
        state = current.content.state
    }

    func end(finalState: WorkoutActivityAttributes.ContentState? = nil) {
        guard let activity else { return }
        let state = finalState ?? self.state
        let content = state.map { ActivityContent(state: $0, staleDate: nil, relevanceScore: 0) }
        Task {
            // `.immediate`: l'allenamento è finito, la Dynamic Island non deve
            // sopravvivergli. Prima restava sulla schermata di blocco altri
            // venti secondi, e in caso di errore anche molto più a lungo.
            await activity.end(content, dismissalPolicy: .immediate)
        }
        self.activity = nil
        self.state = nil
    }

    /// Chiude tutto quello che è rimasto acceso senza una sessione dietro.
    ///
    /// La sessione vive in memoria: se l'app viene chiusa dal multitasking o la
    /// pagina della scheda viene lasciata, nessuno chiude più l'attività e
    /// Dynamic Island e schermata di blocco restano lì per ore. Al primo avvio
    /// utile non c'è nessun allenamento da mostrare, quindi si spegne tutto.
    nonisolated static func endOrphans(exceptSessionID keptSessionID: String? = nil) {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities
            where activity.attributes.sessionID != keptSessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Spegne l'attività di una sessione precisa, anche da fuori dal main actor.
    nonisolated static func end(sessionID: String) {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities
            where activity.attributes.sessionID == sessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
