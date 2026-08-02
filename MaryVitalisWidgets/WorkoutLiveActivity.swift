import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.035, green: 0.059, blue: 0.102))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.exerciseNumber)/\(context.state.totalExercises)",
                          systemImage: "figure.strengthtraining.traditional")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent(context))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    compactStatus(context)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exercise.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isResting {
                        restControls(context, compact: true)
                    } else {
                        setControls(context, compact: true)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(accent(context))
            } compactTrailing: {
                compactStatus(context)
            } minimal: {
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(accent(context))
            }
            .keylineTint(accent(context))
        }
    }

    private func accent(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Color {
        WidgetColor(hex: context.attributes.accentHex).swiftUIColor
    }

    @ViewBuilder
    private func compactStatus(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if context.state.isResting {
            RestTimeText(state: context.state)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(accent(context))
        } else {
            Text("\(context.state.exercise.completedSets)/\(context.state.exercise.totalSets)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(accent(context))
        }
    }

    @ViewBuilder
    private func setControls(_ context: ActivityViewContext<WorkoutActivityAttributes>, compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(1...max(1, min(4, context.state.exercise.totalSets)), id: \.self) { set in
                Button(intent: CompleteWorkoutSetIntent(
                    activityID: context.activityID,
                    targetSet: set,
                    restSeconds: context.state.selectedRestSeconds
                )) {
                    Text(set <= context.state.exercise.completedSets ? "✓" : "\(set)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                        .foregroundStyle(set <= context.state.exercise.completedSets ? Color.black : Color.white)
                        .background(set <= context.state.exercise.completedSets ? accent(context) : Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set <= context.state.exercise.completedSets
                                    ? "Serie \(set), completata"
                                    : "Segna serie \(set)")
            }

            Spacer(minLength: 2)

            let nextRest = nextRestOption(after: context.state.selectedRestSeconds)
            Button(intent: SelectWorkoutRestIntent(activityID: context.activityID, seconds: nextRest)) {
                Label("\(context.state.selectedRestSeconds)s", systemImage: "timer")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .frame(minWidth: compact ? 52 : 64, minHeight: compact ? 36 : 44)
                    .foregroundStyle(accent(context))
                    .background(accent(context).opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func restControls(_ context: ActivityViewContext<WorkoutActivityAttributes>, compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 8) {
            RestTimeText(state: context.state)
                .font(.system(size: compact ? 22 : 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent(context))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: AdjustWorkoutRestIntent(activityID: context.activityID, delta: 15)) {
                Text("+15")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: compact ? 40 : 44, height: compact ? 36 : 44)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(intent: ToggleWorkoutRestIntent(activityID: context.activityID)) {
                Image(systemName: context.state.pausedRestSeconds == nil ? "pause.fill" : "play.fill")
                    .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Button(intent: SkipWorkoutRestIntent(activityID: context.activityID)) {
                Image(systemName: "forward.end.fill")
                    .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                    .background(accent(context), in: Circle())
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
        }
    }

    private func nextRestOption(after current: Int) -> Int {
        let options = [45, 60, 90, 120]
        guard let index = options.firstIndex(of: current) else { return 90 }
        return options[(index + 1) % options.count]
    }
}

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var accent: Color { WidgetColor(hex: context.attributes.accentHex).swiftUIColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(context.attributes.userName, systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Spacer()
                Text("\(context.state.exerciseNumber)/\(context.state.totalExercises) esercizi")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if context.state.isWorkoutComplete {
                Label("Allenamento completato", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.exercise.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.exercise.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if context.state.isResting {
                    liveRestControls
                } else {
                    liveSetControls
                }
            }
        }
        .padding(16)
    }

    private var liveSetControls: some View {
        HStack(spacing: 8) {
            ForEach(1...max(1, min(4, context.state.exercise.totalSets)), id: \.self) { set in
                Button(intent: CompleteWorkoutSetIntent(
                    activityID: context.activityID,
                    targetSet: set,
                    restSeconds: context.state.selectedRestSeconds
                )) {
                    Text(set <= context.state.exercise.completedSets ? "✓" : "\(set)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(set <= context.state.exercise.completedSets ? Color.black : Color.white)
                        .background(set <= context.state.exercise.completedSets ? accent : Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set <= context.state.exercise.completedSets
                                    ? "Serie \(set), completata"
                                    : "Segna serie \(set)")
            }

            Spacer(minLength: 2)

            Button(intent: SelectWorkoutRestIntent(
                activityID: context.activityID,
                seconds: nextRestOption
            )) {
                Label("\(context.state.selectedRestSeconds)s", systemImage: "timer")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .frame(minWidth: 64, minHeight: 44)
                    .foregroundStyle(accent)
                    .background(accent.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recupero \(context.state.selectedRestSeconds) secondi. Tocca per cambiare")
        }
    }

    private var liveRestControls: some View {
        HStack(spacing: 8) {
            RestTimeText(state: context.state)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: AdjustWorkoutRestIntent(activityID: context.activityID, delta: 15)) {
                Text("+15")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(intent: ToggleWorkoutRestIntent(activityID: context.activityID)) {
                Image(systemName: context.state.pausedRestSeconds == nil ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)

            Button(intent: SkipWorkoutRestIntent(activityID: context.activityID)) {
                Image(systemName: "forward.end.fill")
                    .frame(width: 44, height: 44)
                    .background(accent, in: Circle())
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(.plain)
        }
    }

    private var nextRestOption: Int {
        let options = [45, 60, 90, 120]
        guard let index = options.firstIndex(of: context.state.selectedRestSeconds) else { return 90 }
        return options[(index + 1) % options.count]
    }
}

private struct RestTimeText: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let paused = state.pausedRestSeconds {
            Text(format(paused))
        } else if let endsAt = state.restEndsAt, endsAt > Date() {
            Text(timerInterval: Date()...endsAt, countsDown: true)
        } else {
            Text("0:00")
        }
    }

    private func format(_ seconds: Int) -> String {
        "\(max(0, seconds) / 60):" + String(format: "%02d", max(0, seconds) % 60)
    }
}
