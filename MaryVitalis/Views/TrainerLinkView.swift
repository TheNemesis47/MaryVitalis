import SwiftUI

/// Il codice da dettare al proprio trainer.
struct InviteCodeCard: View {
    let account: UserAccount
    let accent: Color

    @EnvironmentObject private var profile: ProfileStore
    @State private var copied = false
    @State private var confirmRegenerate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Il tuo codice")
                .font(.headline)
                .foregroundStyle(Theme.text)

            Panel(padding: 16, radius: Theme.rLg) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(InviteCode.formatted(account.inviteCode))
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(accent)
                            .textSelection(.enabled)
                        Spacer(minLength: 8)
                        Button {
                            UIPasteboard.general.string = account.inviteCode
                            copied = true
                            Feedback.tap()
                        } label: {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                .font(.title3)
                                .foregroundStyle(copied ? Color(hex: "#4ade80") : Theme.textDim)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copia il codice")
                    }

                    Text("Dettalo al tuo trainer perché possa scriverti la scheda. Riceverai una richiesta da accettare: finché non lo fai, nessuno vede i tuoi dati.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Genera un codice nuovo") { confirmRegenerate = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textDim)
                }
            }
        }
        .onChange(of: account.inviteCode) { _, _ in copied = false }
        .alert("Generare un codice nuovo?", isPresented: $confirmRegenerate) {
            Button("Annulla", role: .cancel) {}
            Button("Genera") {
                try? profile.regenerateInviteCode(for: account)
                copied = false
                Feedback.success()
            }
        } message: {
            Text("Il codice attuale smette di funzionare. I trainer già collegati restano collegati.")
        }
    }
}

/// Le richieste di collegamento ricevute, da accettare o rifiutare.
struct PendingRequestsSection: View {
    let account: UserAccount

    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        let requests = profile.pendingRequests(for: account)

        if !requests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Richieste di collegamento")
                    .font(.headline)
                    .foregroundStyle(Theme.text)

                ForEach(requests, id: \.id) { request in
                    requestRow(request)
                }
            }
        }
    }

    private func requestRow(_ request: TrainerLink) -> some View {
        let trainer = profile.account(id: request.trainerAccountID)
        return Panel(padding: 14, radius: Theme.rLg) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: "#f59e0b"))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: "#f59e0b").opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(trainer?.displayName ?? "Un trainer")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text("Vuole seguirti: potrà vedere e modificare le tue schede e vedere il tuo recap.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                }

                HStack(spacing: 8) {
                    Button("Rifiuta") {
                        try? profile.respond(to: request, accept: false)
                        Feedback.tap()
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button("Accetta") {
                        try? profile.respond(to: request, accept: true)
                        Feedback.success()
                    }
                    .buttonStyle(PrimaryButtonStyle(accent: Color(hex: "#4ade80")))
                }
            }
        }
    }
}

/// I clienti seguiti, con l'aggiunta tramite codice.
struct ClientsSection: View {
    let trainer: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @State private var showAdd = false
    @State private var revoking: TrainerLink?

    var body: some View {
        let clients = profile.clients(of: trainer)

        VStack(alignment: .leading, spacing: 10) {
            Text("I tuoi clienti")
                .font(.headline)
                .foregroundStyle(Theme.text)

            if clients.isEmpty {
                Text("Nessun cliente collegato. Chiedi il codice a chi vuoi seguire e aggiungilo qui.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(clients, id: \.id) { client in
                    clientRow(client)
                }
            }

            Button("＋  Aggiungi un cliente con il codice") { showAdd = true }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAdd) {
            AddClientSheet(trainer: trainer).environmentObject(profile)
        }
    }

    private func clientRow(_ client: UserAccount) -> some View {
        let accent = Color(hex: client.accentHex)
        return Panel(padding: 13, radius: Theme.rLg) {
            HStack(spacing: 12) {
                Image(systemName: client.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(Fmt.plural(client.orderedRoutines.count, "scheda", "schede"))
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 8)

                Button {
                    revoking = profile.linkBetween(trainer: trainer.id, client: client.id)
                } label: {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Smetti di seguire \(client.displayName)")
            }
        }
        .alert("Smettere di seguire \(client.displayName)?",
               isPresented: Binding(get: { revoking != nil },
                                    set: { if !$0 { revoking = nil } })) {
            Button("Annulla", role: .cancel) { revoking = nil }
            Button("Smetti di seguire", role: .destructive) {
                if let revoking { try? profile.revoke(revoking) }
                revoking = nil
                Feedback.tap()
            }
        } message: {
            Text("Le schede che gli hai scritto restano sue. Puoi ricollegarti in futuro con un nuovo codice.")
        }
    }
}

/// Inserimento del codice dettato dal cliente.
struct AddClientSheet: View {
    let trainer: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var sentTo: String?
    @State private var busy = false
    @FocusState private var focused: Bool

    private var normalized: String { InviteCode.normalize(code) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(eyebrow: "NUOVO CLIENTE",
                               title: "Inserisci il codice",
                               subtitle: "Il codice a \(InviteCode.length) caratteri che trovi nelle impostazioni del tuo cliente.")

                    if let sentTo {
                        Panel(padding: 15, radius: Theme.rLg) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Richiesta inviata a \(sentTo)", systemImage: "paperplane.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color(hex: "#4ade80"))
                                Text("Comparirà fra i tuoi clienti appena accetta dal suo telefono.")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        TextField("K7M-2QX", text: $code)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .submitLabel(.go)
                            .onSubmit(submit)
                            .padding(.vertical, 16)
                            .background(Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                                .stroke(errorMessage == nil ? Theme.border : Color(hex: "#fb7185"),
                                        lineWidth: 1))

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "#fb7185"))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button("Invia la richiesta", action: submit)
                            .buttonStyle(PrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                            .disabled(!InviteCode.isValid(normalized))
                            .opacity(InviteCode.isValid(normalized) ? 1 : 0.5)

                        Text("Il cliente deve accettare prima che tu possa vedere o modificare le sue schede.")
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
                    Button(sentTo == nil ? "Annulla" : "Fine") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.bg)
        .onAppear { focused = true }
    }

    private func submit() {
        Task { await send() }
    }

    /// Cerca il cliente sul cloud: sul telefono del trainer quel profilo non
    /// esiste, ed è esattamente il caso che deve funzionare.
    private func send() async {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        do {
            let link = try await profile.requestLinkInCloud(toClientWithCode: normalized,
                                                            trainer: trainer)
            // Il nome resta nascosto finché il cliente non accetta.
            sentTo = profile.account(id: link.clientAccountID)?.displayName ?? "il cliente"
            focused = false
            Feedback.success()
        } catch {
            errorMessage = error.localizedDescription
            Feedback.tap()
        }
        busy = false
    }
}
