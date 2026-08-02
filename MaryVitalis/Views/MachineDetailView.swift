import SwiftUI

/// Scheda essenziale dell'attrezzo: identità, gruppi muscolari, esercizi e uso.
struct MachineDetailView: View {
    let machine: GymMachine
    let gym: GymLocation

    @EnvironmentObject private var library: ExerciseLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ExerciseDetail?

    private var zone: GymZone? { gym.zone(for: machine) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero

                if machine.uncertain {
                    uncertaintyNotice
                }

                muscleSection
                locationSection

                if !relatedExercises.isEmpty {
                    exercisesSection
                }

                if !machine.howTo.isEmpty {
                    instructionsSection
                }

                if !machine.tips.isEmpty {
                    tipsSection
                }
            }
            .padding(18)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Chiudi") { dismiss() }
            }
        }
        .sheet(item: $detail) { ExerciseDetailView(detail: $0) }
    }

    private var hero: some View {
        Panel(padding: 18, radius: Theme.rXl) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: machine.category.symbol)
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(machine.category.color)
                    .frame(width: 62, height: 62)
                    .background(machine.category.color.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(machine.category.color.opacity(0.34), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(machine.category.rawValue.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.15)
                        .foregroundStyle(machine.category.color)
                    Text(machine.name)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = machine.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Gruppi allenati", symbol: "figure.arms.open", color: machine.category.color)

            if machine.muscles.isEmpty {
                Text("Gruppi muscolari non ancora classificati")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textFaint)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    ForEach(machine.muscles, id: \.self) { muscle in
                        Label(muscle, systemImage: "circle.hexagongrid.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(machine.category.color)
                            .padding(.horizontal, 11)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                            .background(machine.category.color.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(machine.category.color.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        Panel(padding: 14, radius: Theme.rLg) {
            HStack(spacing: 13) {
                Image(systemName: zone?.symbol ?? "mappin.and.ellipse")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(zone?.color ?? Theme.defaultAccent)
                    .frame(width: 42, height: 42)
                    .background((zone?.color ?? Theme.defaultAccent).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(zone?.name ?? "Sala principale")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("\(gym.displayName) · \(gym.city)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                    if let subtitle = zone?.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                Spacer(minLength: 8)
            }
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Esercizi compatibili", symbol: "list.bullet.rectangle.portrait.fill",
                         color: machine.category.color)

            VStack(spacing: 8) {
                ForEach(relatedExercises) { exercise in
                    Button {
                        detail = ExerciseDetail(exercise: exercise, note: nil)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(machine.category.color)
                                .frame(width: 40, height: 40)
                                .background(machine.category.color.opacity(0.1), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                    .multilineTextAlignment(.leading)
                                Text([exercise.muscleGroup, exercise.target, exercise.bodyPart]
                                    .compactMap { $0 }
                                    .prefix(2)
                                    .joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textFaint)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textFaint)
                        }
                        .frame(minHeight: 50)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Come si usa", symbol: "list.number", color: machine.category.color)

            ForEach(Array(machine.howTo.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color(hex: "#07101b"))
                        .frame(width: 26, height: 26)
                        .background(machine.category.color, in: Circle())
                    Text(step)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Da sapere", symbol: "exclamationmark.triangle.fill",
                         color: Color(hex: "#fbbf24"))

            ForEach(machine.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#fbbf24"))
                        .frame(width: 18)
                    Text(tip)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#fbbf24").opacity(0.07),
                    in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .stroke(Color(hex: "#fbbf24").opacity(0.25), lineWidth: 1)
        )
    }

    private var uncertaintyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(Color(hex: "#fbbf24"))
            Text("Identificazione da verificare in sede: il nome nasce dalla vecchia piantina e potrebbe non coincidere con la targhetta attuale.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(Color(hex: "#fbbf24").opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
    }

    private func sectionTitle(_ title: String, symbol: String, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.text)
            .symbolRenderingMode(.hierarchical)
            .tint(color)
    }

    private var relatedExercises: [Exercise] {
        let queries = RoutineData.all
            .flatMap(\.days)
            .flatMap(\.exercises)
            .map(\.query)

        var seen = Set<String>()
        var result: [Exercise] = []
        for query in queries where !seen.contains(query) {
            guard GymCatalog.machines(for: query, in: gym).contains(where: { $0.id == machine.id }) else { continue }
            seen.insert(query)
            if let exercise = library.find(query) { result.append(exercise) }
        }
        return result
    }
}
