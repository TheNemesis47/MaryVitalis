import ActivityKit
import Foundation

@MainActor
final class WorkoutActivityManager {
    private(set) var activity: Activity<WorkoutActivityAttributes>?
    private(set) var state: WorkoutActivityAttributes.ContentState?

    func start(attributes: WorkoutActivityAttributes,
               state initialState: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        for existing in Activity<WorkoutActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }

        do {
            let content = ActivityContent(state: initialState, staleDate: nil, relevanceScore: 1)
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
        let staleDate = newState.restEndsAt
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
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(20)))
        }
        self.activity = nil
        self.state = nil
    }
}
