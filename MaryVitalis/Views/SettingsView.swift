import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    @State private var showPasswordSheet = false
    @State private var showLinkSheet = false
    @State private var confirmDelete = false
    @State private var deleteError: String?

    private var accent: Color { Color(hex: profile.viewedAccount?.accentHex ?? "#38bdf8") }
    private var viewedName: String { profile.viewedAccount?.displayName ?? "—" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeader(
                        eyebrow: "PERSONALIZZAZIONE",
                        title: "Impostazioni",
                        subtitle: "Scegli chi usa l'app e il recupero da proporre durante l'allenamento."
                    )

                    if AppDatabase.isEphemeral {
                        ephemeralWarning
                    }
                    if profile.account?.mustChangePassword == true {
                        changePasswordPrompt
                    }

                    profileSection

                    if let account = profile.account {
                        PendingRequestsSection(account: account)
                        InviteCodeCard(account: account, accent: accent)
                        if account.userRole == .trainer || account.userRole == .admin {
                            ClientsSection(trainer: account)
                        }
                    }

                    restSection
                    widgetSection
                    securitySection
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
        .sheet(isPresented: $showPasswordSheet) {
            if let account = profile.account {
                PasswordSheet(account: account).environmentObject(profile)
            }
        }
        .sheet(isPresented: $showLinkSheet) {
            if let account = profile.account {
                LinkToCloudSheet(account: account).environmentObject(profile)
            }
        }
        .alert("Eliminare il profilo \(profile.account?.displayName ?? "")?",
               isPresented: $confirmDelete) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive, action: deleteAccount)
        } message: {
            Text("Spariscono schede, palestre, progressi e storico di questo profilo. L'operazione non si può annullare.")
        }
    }

    /// Il database non si è aperto e si sta lavorando in memoria: senza avviso
    /// l'utente si allenerebbe e al riavvio non troverebbe più niente.
    private var ephemeralWarning: some View {
        Panel(padding: 15, radius: Theme.rLg) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color(hex: "#fbbf24"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("I dati non vengono salvati")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text("Il database non si è aperto e l'app sta lavorando in memoria: quello che fai adesso andrà perso alla chiusura. Riavvia l'app; se il problema resta, reinstallala.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var changePasswordPrompt: some View {
        Button { showPasswordSheet = true } label: {
            Panel(padding: 15, radius: Theme.rLg) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cambia la password iniziale")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text("Questo profilo usa ancora la password assegnata al primo avvio. Toccami per sceglierne una tua.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.headline)
                .foregroundStyle(Theme.text)

            if let account = profile.account {
                Panel(padding: 15, radius: Theme.rLg) {
                    HStack(spacing: 13) {
                        Image(systemName: account.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 44, height: 44)
                            .background(accent.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.displayName)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text(account.userRole.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accent)
                        }
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(Theme.textFaint)
                    }
                }

                if account.userRole == .trainer {
                    let clients = profile.visibleAccounts
                        .filter { $0.id != account.id }
                        .map(\.displayName)
                    Text(clients.isEmpty ? "Nessun cliente assegnato."
                                         : "Clienti assegnati: \(clients.formatted(.list(type: .and))).")
                        .font(.footnote)
                        .foregroundStyle(Theme.textFaint)
                }
            }

            // Si sceglie una **persona**, non una scheda: un profilo può averne
            // più di una, e il recap è della persona.
            if profile.visibleAccounts.count > 1 {
                Text("Profilo consultato")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
                    .padding(.top, 4)

                ForEach(profile.visibleAccounts, id: \.id) { user in
                    let selected = profile.viewedAccountID == user.id
                    let userAccent = Color(hex: user.accentHex)
                    Button {
                        profile.viewAccount(user.id)
                        store.activate(accountID: user.id)
                        Feedback.tap()
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(selected ? userAccent : Theme.textFaint)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.text)
                                Text(user.userRole.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer(minLength: 8)
                            Text(Fmt.plural(user.orderedRoutines.count, "scheda", "schede"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(userAccent)
                        }
                        .frame(minHeight: 52)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selected ? userAccent.opacity(0.11) : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                                .stroke(selected ? userAccent.opacity(0.55) : Theme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(user.displayName), \(user.userRole.title)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            Text("Schede, recap e widget usano sempre il profilo consultato: \(viewedName).")
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
                            .background(store.restDefault == seconds ? accent : Theme.surface,
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

            Stepper(value: $store.restDefault, in: 15...600, step: 15) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Durata personalizzata")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    Text("\(store.restDefault) secondi")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(accent)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
            .accessibilityHint("Regola il recupero a intervalli di 15 secondi")
        }
    }

    private var widgetSection: some View {
        Panel(padding: 16, radius: Theme.rLg) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accent)
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

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sessione e sicurezza")
                .font(.headline)
                .foregroundStyle(Theme.text)

            Text(sessionDescription)
                .font(.footnote)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            if let account = profile.account,
               account.firebaseUID == nil,
               FirebaseService.isConfigured {
                Button {
                    showLinkSheet = true
                } label: {
                    Label("Collega questo profilo al cloud", systemImage: "icloud.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(GhostButtonStyle())

                Text("Questo profilo esiste solo su questo iPhone. Collegandolo potrai accedere da qualsiasi dispositivo, e le tue schede e il tuo storico ti seguiranno.")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let account = profile.account, account.appleUserID == nil {
                Button {
                    showPasswordSheet = true
                } label: {
                    Label(CredentialStore.hasPassword(for: account.id)
                          ? "Cambia password" : "Imposta una password",
                          systemImage: "key.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(GhostButtonStyle())
            }

            Button(role: .destructive) {
                profile.signOut()
                dismiss()
            } label: {
                Label("Esci dall’account", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(GhostButtonStyle())

            deleteSection
        }
    }

    private var sessionDescription: String {
        if profile.account?.appleUserID != nil {
            return "Accesso con Apple: l'identità è il tuo Apple ID e i dati seguono te sui tuoi dispositivi. Puoi revocare l'accesso dalle impostazioni di iOS."
        }
        return "L'identificativo della sessione e l'impronta della password sono nel Portachiavi di iOS. La password in chiaro non viene mai salvata."
    }

    /// Richiesta dalla linea guida App Store 5.1.1(v): chi può creare un
    /// account deve poterlo cancellare dall'app, non solo disconnettersi.
    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Elimina il profilo", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(GhostButtonStyle())
            .tint(Color(hex: "#fb7185"))

            Text("Cancella per sempre schede, palestre, progressi e storico di questo profilo. Non si può annullare.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)

            if let deleteError {
                Label(deleteError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#fb7185"))
            }
        }
        .padding(.top, 6)
    }

    private func deleteAccount() {
        guard let account = profile.account else { return }
        Task {
            do {
                try await profile.deleteAccountEverywhere(account)
                Feedback.success()
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

/// Cambio password del profilo locale. Se il profilo non ne ha ancora una —
/// caso di chi arriva da una versione che le password non le aveva — la chiede
/// e basta, senza domandare quella attuale.
struct PasswordSheet: View {
    let account: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var next = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?

    private var needsCurrent: Bool { CredentialStore.hasPassword(for: account.id) }
    private var canSubmit: Bool {
        next.count >= ProfileStore.minimumPasswordLength && next == confirmation
            && (!needsCurrent || !current.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "SICUREZZA",
                               title: needsCurrent ? "Cambia password" : "Imposta una password",
                               subtitle: "Protegge il profilo dalle altre persone che usano questo iPhone.")

                    if needsCurrent {
                        secure("Password attuale", text: $current)
                    }
                    secure("Nuova password", text: $next)
                    Text("Almeno \(ProfileStore.minimumPasswordLength) caratteri.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                    secure("Ripeti la nuova password", text: $confirmation)

                    if !confirmation.isEmpty && next != confirmation {
                        Text("Le due password non coincidono.")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#fb7185"))
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("Salva", action: submit)
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.5)
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
    }

    private func secure(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textContentType(.newPassword)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
    }

    private func submit() {
        errorMessage = nil
        do {
            try profile.changePassword(for: account, current: current, new: next)
            Feedback.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Feedback.tap()
        }
    }
}

/// Promozione di un profilo locale ad account cloud.
///
/// Serve ai profili nati dalla migrazione: esistono su un telefono solo, senza
/// email, e senza un'identità cloud un trainer non può seguire nessuno.
/// Schede, storico e codice invito restano quelli: cambia solo dove vivono.
struct LinkToCloudSheet: View {
    let account: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var busy = false

    private var canSubmit: Bool {
        email.contains("@")
            && password.count >= ProfileStore.minimumPasswordLength
            && password == confirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "CLOUD",
                               title: "Collega \(account.displayName)",
                               subtitle: "Scegli email e password: da qui in poi potrai accedere da qualsiasi dispositivo con queste credenziali.")

                    field("Email", text: $email, secure: false)
                    secure("Password", text: $password)
                    Text("Almeno \(ProfileStore.minimumPasswordLength) caratteri.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                    secure("Ripeti la password", text: $confirmation)

                    if !confirmation.isEmpty && password != confirmation {
                        Text("Le due password non coincidono.")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#fb7185"))
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#fb7185"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await link() }
                    } label: {
                        if busy {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 22)
                        } else {
                            Text("Collega").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit || busy)
                    .opacity(canSubmit && !busy ? 1 : 0.5)

                    Text("Le \(Fmt.plural(account.orderedRoutines.count, "scheda", "schede")) di questo profilo verranno caricate sul cloud. La password locale non servirà più: da qui in poi conta solo questa.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
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
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool) -> some View {
        TextField(title, text: text)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
    }

    private func secure(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .textContentType(.newPassword)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
    }

    private func link() async {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        do {
            try await profile.linkToCloud(account: account,
                                          email: email.trimmingCharacters(in: .whitespaces),
                                          password: password)
            Feedback.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }
}
