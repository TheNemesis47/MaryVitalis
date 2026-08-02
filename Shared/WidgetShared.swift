import ActivityKit
import Foundation

enum MaryVitalisShared {
    static let appGroupIdentifier = "group.it.maryvitalis.shared"
    static let streakWidgetKind = "MaryVitalisWorkoutStreak"

    private static let snapshotKey = "mv:widget-snapshot"
    private static let selectedUserKey = "mv:selected-user"
    private static let commandQueueKey = "mv:widget-command-queue"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var selectedUserID: String {
        get { defaults.string(forKey: selectedUserKey) ?? "samuel" }
        set { defaults.set(newValue, forKey: selectedUserKey) }
    }

    static func loadSnapshot() -> WorkoutWidgetSnapshot {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WorkoutWidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    static func saveSnapshot(_ snapshot: WorkoutWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func enqueue(_ command: WorkoutWidgetCommand) {
        var commands = allCommands()
        commands.append(command)
        // Evita che comandi molto vecchi rimangano per sempre se l'app non viene aperta.
        commands = Array(commands.suffix(40))
        saveCommands(commands)
    }

    static func consumeCommands(sessionID: String) -> [WorkoutWidgetCommand] {
        let commands = allCommands()
        let matching = commands.filter { $0.sessionID == sessionID }
        saveCommands(commands.filter { $0.sessionID != sessionID })
        return matching.sorted { $0.createdAt < $1.createdAt }
    }

    private static func allCommands() -> [WorkoutWidgetCommand] {
        guard let data = defaults.data(forKey: commandQueueKey),
              let commands = try? JSONDecoder().decode([WorkoutWidgetCommand].self, from: data) else {
            return []
        }
        return commands
    }

    private static func saveCommands(_ commands: [WorkoutWidgetCommand]) {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults.set(data, forKey: commandQueueKey)
    }
}

struct WorkoutWidgetSnapshot: Codable, Hashable {
    var userID: String
    var userName: String
    var accentHex: String
    var lastWorkoutDate: Date?
    var updatedAt: Date

    static let placeholder = WorkoutWidgetSnapshot(
        userID: "samuel",
        userName: "Samuel",
        accentHex: "#38bdf8",
        lastWorkoutDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        updatedAt: Date()
    )
}

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ExerciseSummary: Codable, Hashable {
        var index: Int
        var name: String
        var details: String
        var completedSets: Int
        var totalSets: Int

        var isCardio: Bool {
            details.range(of: "min", options: .caseInsensitive) != nil
        }
    }

    struct ContentState: Codable, Hashable {
        var exercise: ExerciseSummary
        var upcoming: [ExerciseSummary]
        var exerciseNumber: Int
        var totalExercises: Int
        var selectedRestSeconds: Int
        var restEndsAt: Date?
        var pausedRestSeconds: Int?
        var isWorkoutComplete: Bool
        var updatedAt: Date

        var isResting: Bool { restEndsAt != nil || pausedRestSeconds != nil }
    }

    var sessionID: String
    var routineID: String
    var routineName: String
    var userName: String
    var dayIndex: Int
    var accentHex: String
    var startedAt: Date
}

struct WorkoutWidgetCommand: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case setDone
        case restPreference
        case restChanged
    }

    var id = UUID()
    var kind: Kind
    var activityID: String
    var sessionID: String
    var routineID: String
    var dayIndex: Int
    var exerciseIndex: Int?
    var completedSets: Int?
    var restSeconds: Int?
    var restEndsAt: Date?
    var pausedRestSeconds: Int?
    var createdAt = Date()
}
