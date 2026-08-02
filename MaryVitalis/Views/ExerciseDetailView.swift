import SwiftUI

struct ExerciseDetail: Identifiable {
    var id: String { exercise.id }
    let exercise: Exercise
    /// La riga della scheda ("4 serie x 12 ripetizioni"), quando si arriva da lì.
    let note: String?
}

/// La card della griglia esercizi.
struct ExerciseCard: View {
    let exercise: Exercise
    var note: String?
    var index: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(url: exercise.imageURL)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    if let index {
                        Text("\(index)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: "#0a0f1a"))
                            .frame(width: 24, height: 24)
                            .background(Theme.defaultAccent, in: Circle())
                            .padding(8)
                    }
                }
                .background(Color.white.opacity(0.03))

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let note {
                        Text("⏱️ \(note)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.defaultAccent)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 5) {
                        if let target = exercise.target {
                            TinyTag(text: target, accent: true)
                        }
                        if let equipment = exercise.equipment {
                            TinyTag(text: equipment)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TinyTag: View {
    let text: String
    var accent = false

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(accent ? Theme.defaultAccent : Theme.textFaint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(accent ? Theme.defaultAccent.opacity(0.12) : Theme.surfaceHi, in: Capsule())
    }
}

/// La scheda completa dell'esercizio: animazione, dati e passi.
struct ExerciseDetailView: View {
    let detail: ExerciseDetail
    @Environment(\.dismiss) private var dismiss

    private var exercise: Exercise { detail.exercise }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RemoteImage(url: exercise.gifURL, animated: true)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))

                    Text(exercise.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.text)

                    if let note = detail.note {
                        Text("⏱️ \(note)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.defaultAccent)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        specTile("Muscolo target", exercise.target)
                        specTile("Attrezzo", exercise.equipment)
                        specTile("Distretto", exercise.bodyPart)
                        if !exercise.secondaryMuscles.isEmpty {
                            specTile("Muscoli secondari", exercise.secondaryMuscles.joined(separator: ", "))
                        }
                    }

                    if !machines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📍 Dove si fa")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.text)
                            ForEach(machines) { machine in
                                NavigationLink {
                                    MachineDetailView(machine: machine, gym: GymCatalog.defaultLocation)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: machine.category.symbol)
                                            .foregroundStyle(machine.category.color)
                                        Text(machine.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Theme.textFaint)
                                    }
                                    .padding(12)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.rMd).stroke(Theme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    let steps = exercise.steps
                    if !steps.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📝 Come eseguirlo")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.text)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color(hex: "#0a0f1a"))
                                        .frame(width: 22, height: 22)
                                        .background(Theme.defaultAccent, in: Circle())
                                    Text(step)
                                        .font(.system(size: 14.5))
                                        .foregroundStyle(Theme.textDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    Text("Media © Gym Visual")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                        .padding(.top, 8)
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
        }
        .presentationBackground(Theme.bg)
    }

    /// Gli attrezzi della sala su cui si esegue questo esercizio.
    private var machines: [GymMachine] {
        GymCatalog.machines(for: exercise.name)
    }

    private func specTile(_ label: String, _ value: String?) -> some View {
        Panel(padding: 12, radius: Theme.rMd) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.textFaint)
                Text(value.map { Fmt.capitalizedFirst($0) } ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Immagini e GIF del dataset, caricate dalla rete con cache di sistema.
struct RemoteImage: View {
    let url: URL?
    var animated = false

    var body: some View {
        if let url {
            AnimatedImageView(url: url)
        } else {
            placeholder(symbol: "photo")
        }
    }

    private func placeholder(symbol: String?) -> some View {
        ZStack {
            Theme.surfaceHi
            if let symbol {
                Image(systemName: symbol).foregroundStyle(Theme.textFaint)
            } else {
                ProgressView()
            }
        }
    }
}
