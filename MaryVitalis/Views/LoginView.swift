import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var cloud: CloudSync

    @State private var selected: UserAccount?
    @State private var password = ""
    @State private var failed = false
    @State private var showRegister = false
    @State private var appleError: String?
    @State private var appleAccountIsNew = false
    @State private var cloudEmail = ""
    @State private var cloudPassword = ""
    @State private var cloudError: String?
    @State private var resetSent = false
    @State private var busy = false
    @FocusState private var passwordFocused: Bool

    /// Solo i profili di questo telefono: gli account cloud si aprono con Apple
    /// o con email e password, e i segnaposto delle altre persone non sono
    /// profili — sono il modo in cui l'app rappresenta un collegamento.
    private var accounts: [UserAccount] { profile.selectableAccounts }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if FirebaseService.isConfigured {
                    cloudSignIn
                }

                if accounts.isEmpty {
                    firstRun
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scegli profilo")
                            .font(.headline)
                            .foregroundStyle(Theme.text)

                        ForEach(accounts, id: \.id) { account in
                            accountRow(account)
                        }
                    }

                    createAccountButton
                }

                appleSection

                Label("I profili locali servono a più persone sullo stesso iPhone: la password resta qui, protetta dal Portachiavi. Con Apple i tuoi dati seguono te su tutti i tuoi dispositivi.",
                      systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background { Theme.background }
        .sheet(isPresented: $showRegister) {
            RegisterView().environmentObject(profile).environmentObject(cloud)
        }
        .fullScreenCover(isPresented: $appleAccountIsNew) {
            if let account = profile.account {
                StarterRoutineView(account: account) { appleAccountIsNew = false }
                    .environmentObject(cloud)
                    .environmentObject(profile)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.defaultAccent)
                .frame(width: 64, height: 64)
                .background(Theme.defaultAccent.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("MARY VITALIS")
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(Theme.textFaint)
            Text(accounts.isEmpty ? "Benvenuto" : "Accedi")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(accounts.isEmpty
                 ? "Crea il tuo profilo e scegli da quale scheda partire."
                 : "Il profilo scelto determina schede, recupero, widget e recap.")
                .font(.body)
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Accesso a un account che esiste già, anche da un dispositivo che non
    /// l'ha mai visto. È la cosa che i soli profili locali non potevano fare.
    private var cloudSignIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hai già un account?")
                .font(.headline)
                .foregroundStyle(Theme.text)

            TextField("Email", text: $cloudEmail)
                .onChange(of: cloudEmail) { _, _ in resetSent = false }
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1))

            SecureField("Password", text: $cloudPassword)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { Task { await cloudLogin() } }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .stroke(cloudError == nil ? Theme.border : Color(hex: "#fb7185"), lineWidth: 1))

            if let cloudError {
                Label(cloudError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#fb7185"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await cloudLogin() }
            } label: {
                if busy {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 22)
                } else {
                    Text("Accedi").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || cloudEmail.isEmpty || cloudPassword.isEmpty)
            .opacity(busy || cloudEmail.isEmpty || cloudPassword.isEmpty ? 0.5 : 1)

            // La password di un account cloud non è recuperabile da qui: la
            // verifica Firebase, e l'unico modo di rientrare è farsene mandare
            // una nuova. Senza questo tasto, chi la dimentica resta fuori.
            if resetSent {
                Label("Ti abbiamo mandato un'email per scegliere una password nuova. Controlla anche lo spam.",
                      systemImage: "envelope.badge.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#4ade80"))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Password dimenticata?") { Task { await resetPassword() } }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textDim)
                    .disabled(busy || cloudEmail.isEmpty)
                    .opacity(cloudEmail.isEmpty ? 0.5 : 1)
            }
        }
    }

    private func resetPassword() async {
        guard !busy else { return }
        busy = true
        cloudError = nil
        do {
            try await AuthService.sendPasswordReset(
                email: cloudEmail.trimmingCharacters(in: .whitespaces))
            resetSent = true
            Feedback.success()
        } catch {
            cloudError = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }

    private func cloudLogin() async {
        guard !busy else { return }
        busy = true
        cloudError = nil
        do {
            try await profile.signInToCloud(email: cloudEmail.trimmingCharacters(in: .whitespaces),
                                            password: cloudPassword)
            Feedback.success()
        } catch {
            cloudError = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }

    private var firstRun: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Crea il tuo profilo") { showRegister = true }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var createAccountButton: some View {
        Button("＋  Aggiungi un altro profilo") { showRegister = true }
            .buttonStyle(GhostButtonStyle())
            .frame(maxWidth: .infinity)
    }

    private var appleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.border).frame(height: 1)
                Text("oppure")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
                // Impedisce che qualcuno riusi un token Apple intercettato:
                // Apple lo firma dentro il token e Firebase verifica che
                // corrisponda a quello generato per *questa* richiesta.
                request.nonce = AuthService.makeAppleNonce()
            } onCompletion: { result in
                Task { await handleApple(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))

            Text("Sincronizza schede e progressi fra i tuoi dispositivi.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)

            if let appleError {
                Label(appleError, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#fb7185"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        appleError = nil
        switch result {
        case .success(let authorization):
            do {
                let appleID = try AppleSignIn.credential(from: authorization).userID
                let cloudUser = try await AuthService.signIn(with: authorization)
                let outcome = try await profile.signInWithApple(cloudUser: cloudUser,
                                                                appleUserID: appleID)
                Feedback.success()
                appleAccountIsNew = outcome.isNew
            } catch {
                appleError = error.localizedDescription
            }

        case .failure(let error):
            // L'annullamento dell'utente non è un errore da mostrare.
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            appleError = error.localizedDescription
        }
    }

    private func accountRow(_ account: UserAccount) -> some View {
        let isSelected = selected?.id == account.id

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                // Un profilo senza password si apre subito: aprire un campo
                // password che non serve a niente sarebbe solo un ostacolo.
                guard !profile.opensWithoutPassword(account) else {
                    attemptSignIn(account)
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isSelected {
                        collapse()
                    } else {
                        selected = account
                        password = ""
                        failed = false
                    }
                }
                passwordFocused = !isSelected
            } label: {
                accountLabel(account, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profilo \(account.displayName), ruolo \(account.userRole.title)")

            if isSelected {
                passwordField(for: account)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
            .stroke(isSelected ? roleColor(account.userRole) : Theme.border, lineWidth: 1))
    }

    private func accountLabel(_ account: UserAccount, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: account.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(roleColor(account.userRole))
                .frame(width: 46, height: 46)
                .background(roleColor(account.userRole).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(account.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(account.userRole.title.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.7)
                        .foregroundStyle(roleColor(account.userRole))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(roleColor(account.userRole).opacity(0.12), in: Capsule())
                }
                Text(account.userRole.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)
            Image(systemName: isSelected ? "chevron.up.circle.fill" : "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(roleColor(account.userRole))
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func passwordField(for account: UserAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($passwordFocused)
                .onSubmit { attemptSignIn(account) }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                    .stroke(failed ? Color(hex: "#fb7185") : Theme.border, lineWidth: 1))

            if failed {
                Label("Password non corretta.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#fb7185"))
            }

            Button("Accedi") { attemptSignIn(account) }
                .buttonStyle(PrimaryButtonStyle(accent: roleColor(account.userRole)))
                .disabled(password.isEmpty)
                .opacity(password.isEmpty ? 0.5 : 1)
        }
    }

    private func attemptSignIn(_ account: UserAccount) {
        // Un profilo **locale** senza password resta accessibile senza: è il
        // caso di chi viene da una versione che le password non le aveva. Un
        // account cloud no, mai: quello si apre da sopra, con Apple o con email
        // e password.
        let ok = profile.opensWithoutPassword(account)
            ? { profile.signIn(account: account); return true }()
            : profile.signIn(account: account, password: password)

        if ok {
            Feedback.success()
            collapse()
        } else {
            failed = true
            password = ""
            Feedback.tap()
        }
    }

    private func collapse() {
        selected = nil
        password = ""
        failed = false
        passwordFocused = false
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .member: Theme.defaultAccent
        case .trainer: Color(hex: "#f59e0b")
        case .admin: Color(hex: "#a78bfa")
        }
    }
}
