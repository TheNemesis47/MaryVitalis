import ActivityKit
import AppIntents
import Foundation

struct CompleteWorkoutSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Completa serie"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Attività") var activityID: String
    @Parameter(title: "Serie") var targetSet: Int
    @Parameter(title: "Recupero") var restSeconds: Int

    init() {}

    init(activityID: String, targetSet: Int, restSeconds: Int) {
        self.activityID = activityID
        self.targetSet = targetSet
        self.restSeconds = restSeconds
    }

    func perform() async throws -> some IntentResult {
        guard let activity = WorkoutIntentSupport.activity(id: activityID) else { return .result() }
        var state = activity.content.state
        let originalExercise = state.exercise
        let before = originalExercise.completedSets
        let tapped = min(max(1, targetSet), originalExercise.totalSets)
        let nextCount = tapped > before ? tapped : max(0, tapped - 1)
        let increased = nextCount > before
        state.exercise.completedSets = nextCount
        state.selectedRestSeconds = restSeconds

        var restEndsAt: Date?
        if increased, !originalExercise.isCardio {
            restEndsAt = Date().addingTimeInterval(Double(restSeconds))
            state.restEndsAt = restEndsAt
            state.pausedRestSeconds = nil
        }

        if nextCount >= originalExercise.totalSets {
            if !state.upcoming.isEmpty {
                state.exercise = state.upcoming.removeFirst()
                state.exerciseNumber = state.exercise.index + 1
            } else {
                state.isWorkoutComplete = true
                state.restEndsAt = nil
                state.pausedRestSeconds = nil
                restEndsAt = nil
            }
        }

        state.updatedAt = Date()
        MaryVitalisShared.enqueue(WorkoutWidgetCommand(
            kind: .setDone,
            activityID: activity.id,
            sessionID: activity.attributes.sessionID,
            routineID: activity.attributes.routineID,
            dayIndex: activity.attributes.dayIndex,
            exerciseIndex: originalExercise.index,
            completedSets: nextCount,
            restSeconds: restSeconds,
            restEndsAt: restEndsAt,
            pausedRestSeconds: nil
        ))
        await WorkoutIntentSupport.update(activity, state: state)
        return .result()
    }
}

struct SelectWorkoutRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Scegli recupero"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Attività") var activityID: String
    @Parameter(title: "Secondi") var seconds: Int

    init() {}
    init(activityID: String, seconds: Int) { self.activityID = activityID; self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        guard let activity = WorkoutIntentSupport.activity(id: activityID) else { return .result() }
        var state = activity.content.state
        state.selectedRestSeconds = seconds
        state.updatedAt = Date()
        MaryVitalisShared.enqueue(WorkoutWidgetCommand(
            kind: .restPreference,
            activityID: activity.id,
            sessionID: activity.attributes.sessionID,
            routineID: activity.attributes.routineID,
            dayIndex: activity.attributes.dayIndex,
            exerciseIndex: nil,
            completedSets: nil,
            restSeconds: seconds,
            restEndsAt: state.restEndsAt,
            pausedRestSeconds: state.pausedRestSeconds
        ))
        await WorkoutIntentSupport.update(activity, state: state)
        return .result()
    }
}

struct AdjustWorkoutRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Modifica recupero"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Attività") var activityID: String
    @Parameter(title: "Secondi") var delta: Int

    init() {}
    init(activityID: String, delta: Int) { self.activityID = activityID; self.delta = delta }

    func perform() async throws -> some IntentResult {
        guard let activity = WorkoutIntentSupport.activity(id: activityID) else { return .result() }
        var state = activity.content.state
        let wasPaused = state.pausedRestSeconds != nil
        let remaining = WorkoutIntentSupport.remaining(in: state)
        let next = max(0, remaining + delta)
        state.restEndsAt = !wasPaused && next > 0 ? Date().addingTimeInterval(Double(next)) : nil
        state.pausedRestSeconds = wasPaused && next > 0 ? next : nil
        state.updatedAt = Date()
        await WorkoutIntentSupport.saveRestChange(activity, state: state)
        return .result()
    }
}

struct ToggleWorkoutRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pausa o riprendi recupero"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Attività") var activityID: String

    init() {}
    init(activityID: String) { self.activityID = activityID }

    func perform() async throws -> some IntentResult {
        guard let activity = WorkoutIntentSupport.activity(id: activityID) else { return .result() }
        var state = activity.content.state
        if let paused = state.pausedRestSeconds {
            state.restEndsAt = Date().addingTimeInterval(Double(paused))
            state.pausedRestSeconds = nil
        } else {
            state.pausedRestSeconds = WorkoutIntentSupport.remaining(in: state)
            state.restEndsAt = nil
        }
        state.updatedAt = Date()
        await WorkoutIntentSupport.saveRestChange(activity, state: state)
        return .result()
    }
}

struct SkipWorkoutRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Salta recupero"
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Attività") var activityID: String

    init() {}
    init(activityID: String) { self.activityID = activityID }

    func perform() async throws -> some IntentResult {
        guard let activity = WorkoutIntentSupport.activity(id: activityID) else { return .result() }
        var state = activity.content.state
        state.restEndsAt = nil
        state.pausedRestSeconds = nil
        state.updatedAt = Date()
        await WorkoutIntentSupport.saveRestChange(activity, state: state)
        return .result()
    }
}

private enum WorkoutIntentSupport {
    static func activity(id: String) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    }

    static func remaining(in state: WorkoutActivityAttributes.ContentState) -> Int {
        if let paused = state.pausedRestSeconds { return paused }
        guard let endsAt = state.restEndsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
    }

    static func update(_ activity: Activity<WorkoutActivityAttributes>,
                       state: WorkoutActivityAttributes.ContentState) async {
        await activity.update(ActivityContent(state: state,
                                              staleDate: state.restEndsAt,
                                              relevanceScore: 1))
    }

    static func saveRestChange(_ activity: Activity<WorkoutActivityAttributes>,
                               state: WorkoutActivityAttributes.ContentState) async {
        MaryVitalisShared.enqueue(WorkoutWidgetCommand(
            kind: .restChanged,
            activityID: activity.id,
            sessionID: activity.attributes.sessionID,
            routineID: activity.attributes.routineID,
            dayIndex: activity.attributes.dayIndex,
            exerciseIndex: state.exercise.index,
            completedSets: state.exercise.completedSets,
            restSeconds: state.selectedRestSeconds,
            restEndsAt: state.restEndsAt,
            pausedRestSeconds: state.pausedRestSeconds
        ))
        await update(activity, state: state)
    }
}
