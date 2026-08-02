import SwiftUI
import WidgetKit

struct WorkoutStreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkoutWidgetSnapshot
}

struct WorkoutStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutStreakEntry {
        WorkoutStreakEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutStreakEntry) -> Void) {
        completion(WorkoutStreakEntry(date: Date(), snapshot: MaryVitalisShared.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutStreakEntry>) -> Void) {
        let now = Date()
        let entry = WorkoutStreakEntry(date: now, snapshot: MaryVitalisShared.loadSnapshot())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1,
                                             to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

struct WorkoutStreakWidget: Widget {
    let kind = MaryVitalisShared.streakWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutStreakProvider()) { entry in
            WorkoutStreakView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.035, green: 0.059, blue: 0.102)
                }
        }
        .configurationDisplayName("Ultimo allenamento")
        .description("Mostra da quanti giorni il profilo selezionato non si allena.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

private struct WorkoutStreakView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WorkoutStreakEntry

    private var days: Int? {
        guard let last = entry.snapshot.lastWorkoutDate else { return nil }
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day],
                                               from: calendar.startOfDay(for: last),
                                               to: calendar.startOfDay(for: entry.date)).day ?? 0)
    }

    private var value: String {
        guard let days else { return "—" }
        return "\(days)"
    }

    private var message: String {
        guard let days else { return "Inizia oggi" }
        switch days {
        case 0: return "Allenamento fatto oggi"
        case 1: return "Non ti alleni da 1 giorno"
        default: return "Non ti alleni da \(days) giorni"
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(message, systemImage: "figure.strengthtraining.traditional")

        case .accessoryRectangular:
            HStack(spacing: 9) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.snapshot.userName)
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.headline)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(WidgetColor(hex: entry.snapshot.accentHex))
                    Spacer()
                    Text(entry.snapshot.userName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)

                Text(value)
                    .font(.system(size: family == .systemSmall ? 47 : 40,
                                  weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(days == 1 ? "giorno senza allenarti" : "giorni senza allenarti")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if family == .systemMedium {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(WidgetColor(hex: entry.snapshot.accentHex))
                }
            }
        }
    }
}

struct WidgetColor: ShapeStyle {
    private let color: Color

    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        Scanner(string: cleaned).scanHexInt64(&value)
        color = Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        color.resolve(in: environment)
    }

    var swiftUIColor: Color { color }
}
