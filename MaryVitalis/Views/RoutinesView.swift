import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var profile: ProfileStore

    @State private var editing: Routine?
    @State private var deleting: Routine?

    /// La scheda appartiene al profilo consultato: è così che un trainer ne
    /// costruisce una per un cliente e il cliente se la ritrova.
    private var owner: UserAccount? { profile.viewedAccount }
    private var isForSomeoneElse: Bool {
        owner != nil && owner?.id != profile.signedInAccountID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(eyebrow: "Programmi", title: "Le schede", subtitle: subtitle)

                // Un trainer lavora sulle proprie schede e su quelle dei
                // clienti: passare dall'uno all'altro deve costare un tocco,
                // non un giro dalle impostazioni.
                if profile.visibleAccounts.count > 1 {
                    profileSwitcher
                }

                if isForSomeoneElse, let owner {
                    Label("Stai lavorando sul profilo di \(owner.displayName): le schede che crei sono sue e le troverà sul suo telefono.",
                          systemImage: "person.2.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "#f59e0b"))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(13)
                        .background(Color(hex: "#f59e0b").opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                }

                if profile.visibleRoutines.isEmpty {
                    EmptyStateView(icon: "📋", title: "Nessuna scheda",
                                   message: "Creane una da zero e riempila con gli esercizi che servono.")
                }

                ForEach(profile.visibleRoutines, id: \.id) { routine in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(value: routine.id) {
                            RoutineCard(routine: routine,
                                        workoutsDone: store.completedWorkouts(routine: routine))
                        }
                        .buttonStyle(.plain)
                        // Senza una forma esplicita il tocco prende solo dove
                        // c'è del disegno: è quello che rendeva la card muta.
                        .contentShape(RoundedRectangle(cornerRadius: Theme.rXl, style: .continuous))
                        .contextMenu { menu(for: routine) }

                        // Il menu contestuale resta, ma non basta da solo:
                        // "tieni premuto" non si vede, un bottone sì.
                        Menu {
                            menu(for: routine)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                                .frame(width: 36, height: 36)
                                .background(Theme.surfaceHi, in: Circle())
                        }
                        .padding(12)
                        .accessibilityLabel("Azioni su \(routine.name)")
                    }
                }

                // Un trainer si allena anche lui: prima di scrivere una scheda
                // va detto per chi è, altrimenti finisce nel profilo che
                // capita di stare guardando.
                if candidates.count > 1 {
                    Menu {
                        ForEach(candidates, id: \.id) { person in
                            Button {
                                create(for: person)
                            } label: {
                                Label(person.id == profile.signedInAccountID
                                      ? "Per me (\(person.displayName))"
                                      : person.displayName,
                                      systemImage: person.id == profile.signedInAccountID
                                      ? "person.fill" : person.symbolName)
                            }
                        }
                    } label: {
                        Text("＋  Crea una scheda")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                } else if let owner {
                    Button("＋  Crea una scheda") { create(for: owner) }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .pageBackground()
        .navigationTitle("Schede")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { editing != nil },
                                    set: { if !$0 { editing = nil } })) {
            if let editing {
                NavigationStack { RoutineEditorView(routine: editing) }
                    .presentationBackground(Theme.bg)
            }
        }
        .alert("Eliminare \(deleting?.name ?? "")?",
               isPresented: Binding(get: { deleting != nil },
                                    set: { if !$0 { deleting = nil } })) {
            Button("Annulla", role: .cancel) { deleting = nil }
            Button("Elimina", role: .destructive) {
                if let deleting { profile.delete(deleting) }
                deleting = nil
                Feedback.tap()
            }
        } message: {
            Text("La scheda sparisce anche dagli altri dispositivi. Gli allenamenti già registrati restano nello storico.")
        }
    }

    /// Se stesso più i clienti che segue: le persone per cui può scrivere.
    private var candidates: [UserAccount] {
        guard let account = profile.account else { return [] }
        return [account] + profile.clients(of: account).filter { $0.id != account.id }
    }

    private func create(for person: UserAccount) {
        // La scheda nasce nel profilo di chi la userà, quindi ci si sposta:
        // scriverla "da fuori" vorrebbe dire non vederla dov'è finita.
        if profile.viewedAccountID != person.id {
            profile.viewAccount(person.id)
            store.activate(accountID: person.id)
        }
        editing = profile.createRoutine(for: person)
        Feedback.success()
    }

    @ViewBuilder
    private func menu(for routine: Routine) -> some View {
        Button { editing = routine } label: {
            Label("Modifica", systemImage: "pencil")
        }
        Button {
            profile.duplicate(routine)
            Feedback.tap()
        } label: {
            Label("Duplica", systemImage: "doc.on.doc")
        }
        Button(role: .destructive) { deleting = routine } label: {
            Label("Elimina", systemImage: "trash")
        }
    }

    private var profileSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(profile.visibleAccounts, id: \.id) { account in
                    let selected = profile.viewedAccountID == account.id
                    let tint = Color(hex: account.accentHex)
                    Button {
                        profile.viewAccount(account.id)
                        store.activate(accountID: account.id)
                        Feedback.tap()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: account.id == profile.signedInAccountID
                                  ? "person.fill" : account.symbolName)
                                .font(.system(size: 12, weight: .bold))
                            Text(account.id == profile.signedInAccountID
                                 ? "Le mie" : account.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundStyle(selected ? Color(hex: "#0a0f1a") : Theme.textDim)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 36)
                        .background(selected ? tint : Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(selected ? .clear : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 1)
        }
    }

    private var subtitle: String {
        "Tocca una scheda per aprirla, usa ••• per modificarla, duplicarla o eliminarla."
    }
}
