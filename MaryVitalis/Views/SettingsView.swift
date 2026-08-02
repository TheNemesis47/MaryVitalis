import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeader(
                        eyebrow: "PERSONALIZZAZIONE",
                        title: "Impostazioni",
                        subtitle: "Scegli chi usa l'app e il recupero da proporre durante l'allenamento."
                    )

                    profileSection
                    restSection
                    widgetSection
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.bg)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chi si allena?")
                .font(.headline)
                .foregroundStyle(Theme.text)

            ForEach(RoutineData.all) { user in
                let selected = profile.selectedUserID == user.id
                Button {
                    profile.selectedUserID = user.id
                    store.publishWidgetSnapshot(selectedUserID: user.id)
                    Feedback.tap()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(selected ? user.accent : Theme.textFaint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text(user.goal)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer(minLength: 8)
                        Text("\(user.days.count) giorni")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(user.accent)
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selected ? user.accent.opacity(0.11) : Theme.surface,
                                in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                            .stroke(selected ? user.accent.opacity(0.55) : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(user.name), \(user.goal)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }

            Text("Il widget “Non ti alleni da” usa lo storico della persona selezionata.")
                .font(.footnote)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recupero predefinito")
                .font(.headline)
                .foregroundStyle(Theme.text)

            HStack(spacing: 8) {
                ForEach(WorkoutStore.restOptions, id: \.self) { seconds in
                    Button {
                        store.restDefault = seconds
                        Feedback.tap()
                    } label: {
                        Text("\(seconds)s")
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(store.restDefault == seconds ? Color(hex: "#0a0f1a") : Theme.textDim)
                            .background(store.restDefault == seconds ? profile.selectedRoutine.accent : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(store.restDefault == seconds ? .clear : Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recupero di \(seconds) secondi")
                    .accessibilityAddTraits(store.restDefault == seconds ? .isSelected : [])
                }
            }
        }
    }

    private var widgetSection: some View {
        Panel(padding: 16, radius: Theme.rLg) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(profile.selectedRoutine.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Widget e Lock Screen")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text("Aggiungi il widget dalla schermata Home o dalla Lock Screen. Durante una scheda, la Live Activity mostra esercizio, serie e recupero.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
