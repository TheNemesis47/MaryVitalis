import SwiftUI

/// Creazione di un profilo nuovo. Chiude su un onboarding che chiede da quale
/// scheda partire: un'app di allenamento aperta su una lista vuota non dice
/// niente a nessuno.
struct RegisterView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var role: UserRole = .member
    @State private var errorMessage: String?
    @State private var createdAccount: UserAccount?
    @State private var busy = false

    @FocusState private var focused: Field?

    private enum Field { case name, email, password, confirmation }

    private var passwordsMatch: Bool { !password.isEmpty && password == confirmation }
    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= ProfileStore.minimumPasswordLength
            && passwordsMatch
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeader(eyebrow: "NUOVO PROFILO",
                               title: "Crea il tuo account",
                               subtitle: "Resta su questo iPhone. La password protegge il profilo dagli altri che usano lo stesso telefono.")

                    fields
                    roleSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: submit) {
                        if busy {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 22)
                        } else {
                            Text("Crea profilo").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!canSubmit || busy)
                    .opacity(canSubmit && !busy ? 1 : 0.5)

                    if FirebaseService.isConfigured {
                        Text(email.isEmpty
                             ? "Senza email il profilo resta solo su questo iPhone. Con l'email potrai rientrare da qualsiasi dispositivo."
                             : "L'account viene creato sul cloud: potrai accedere da qualsiasi dispositivo.")
                            .font(.caption)
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.bg)
        // `UserAccount` è un modello SwiftData, non un `Identifiable` utilizzabile
        // con `fullScreenCover(item:)`: si pilota con un booleano.
        .fullScreenCover(isPresented: Binding(
            get: { createdAccount != nil },
            set: { if !$0 { createdAccount = nil } }
        )) {
            if let createdAccount {
                StarterRoutineView(account: createdAccount) { dismiss() }
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Nome", text: $displayName, field: .name, content: .name)
            field("Email (facoltativa)", text: $email, field: .email, content: .emailAddress,
                  keyboard: .emailAddress)

            secureField("Password", text: $password, field: .password)
            Text("Almeno \(ProfileStore.minimumPasswordLength) caratteri.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)

            secureField("Ripeti la password", text: $confirmation, field: .confirmation)
            if !confirmation.isEmpty && !passwordsMatch {
                Text("Le due password non coincidono.")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#fb7185"))
            }
        }
    }

    private func field(_ title: String,
                       text: Binding<String>,
                       field: Field,
                       content: UITextContentType,
                       keyboard: UIKeyboardType = .default) -> some View {
        TextField(title, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .focused($focused, equals: field)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
    }

    private func secureField(_ title: String, text: Binding<String>, field: Field) -> some View {
        SecureField(title, text: text)
            .textContentType(.newPassword)
            .focused($focused, equals: field)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tipo di profilo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textDim)

            Picker("Tipo di profilo", selection: $role) {
                Text(UserRole.member.title).tag(UserRole.member)
                Text(UserRole.trainer.title).tag(UserRole.trainer)
            }
            .pickerStyle(.segmented)

            Text(role.detail)
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
        }
    }

    private func submit() {
        Task { await create() }
    }

    private func create() async {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        focused = nil
        do {
            // Con Firebase configurato l'account nasce sul cloud, così si può
            // rientrare da qualsiasi dispositivo. Senza, resta un profilo
            // locale: l'app deve funzionare comunque.
            let account: UserAccount
            if FirebaseService.isConfigured && !email.isEmpty {
                account = try await profile.registerInCloud(displayName: displayName,
                                                            email: email,
                                                            password: password,
                                                            role: role)
            } else {
                account = try profile.register(displayName: displayName,
                                               email: email.isEmpty ? nil : email,
                                               password: password,
                                               role: role)
                profile.signIn(account: account)
            }
            Feedback.success()
            createdAccount = account
        } catch {
            errorMessage = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }
}

/// Scelta della prima scheda. Le schede di partenza portano il nome
/// dell'obiettivo, non quello delle persone per cui erano nate.
struct StarterRoutineView: View {
    let account: UserAccount
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var cloud: CloudSync
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "PRIMO PASSO",
                               title: "Da dove partiamo?",
                               subtitle: "Scegli una scheda di esempio da adattare, oppure creane una vuota e riempila tu.")

                    ForEach(Array(RoutineFactory.starterTemplates.enumerated()), id: \.offset) { _, seed in
                        templateCard(seed)
                    }

                    Button("Parto da una scheda vuota") { createEmpty() }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(busy)
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(Theme.bg)
        .interactiveDismissDisabled()
    }

    private func templateCard(_ seed: SeedRoutine) -> some View {
        let accent = Color(hex: seed.accentHex)
        return Button { create(from: seed) } label: {
            Panel(padding: 16, radius: Theme.rXl) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text(seed.emoji)
                            .font(.system(size: 24))
                            .frame(width: 48, height: 48)
                            .background(accent.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(RoutineFactory.templateName(for: seed))
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            Text("\(seed.days.count) giorni · \(seed.days.reduce(0) { $0 + $1.exercises.count }) esercizi")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 8)
                    }

                    Text(seed.summary)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textDim)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func create(from seed: SeedRoutine) {
        guard !busy else { return }
        busy = true
        let inserted = RoutineFactory.insert(seed: seed,
                                             named: RoutineFactory.templateName(for: seed),
                                             owner: account,
                                             into: context)
        finish(routine: inserted.routine)
    }

    private func createEmpty() {
        guard !busy else { return }
        busy = true
        let routine = RoutineFactory.insertEmpty(named: "La mia scheda",
                                                 owner: account,
                                                 into: context)
        finish(routine: routine)
    }

    private func finish(routine: Routine) {
        try? context.save()
        Feedback.success()
        // La scheda deve arrivare sul cloud, altrimenti su un altro dispositivo
        // non esiste.
        Task { await cloud.pushRoutine(routine) }
        onDone()
    }
}
