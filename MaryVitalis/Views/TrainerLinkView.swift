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

                if let warning = profile.linkWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "#fbbf24"))
                        .fixedSize(horizontal: false, vertical: true)
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

/// Chi ti segue. Dall'altra parte del legame c'era il vuoto: si accettava una
/// richiesta e poi nell'app non compariva da nessuna parte che qualcuno stesse
/// leggendo le tue schede — che è esattamente la cosa da dire a chiare lettere.
struct TrainersSection: View {
    let account: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @State private var revoking: TrainerLink?

    var body: some View {
        let trainers = profile.trainers(of: account)

        if !trainers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(trainers.count == 1 ? "Il tuo trainer" : "I tuoi trainer")
                    .font(.headline)
                    .foregroundStyle(Theme.text)

                ForEach(trainers, id: \.id) { trainer in
                    trainerRow(trainer)
                }

                Text("Vede le tue schede e il tuo recap, e può scriverti nuove schede. Puoi togliergli l'accesso quando vuoi.")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .alert("Togliere l'accesso a \(revoking.flatMap { profile.account(id: $0.trainerAccountID)?.displayName } ?? "")?",
                   isPresented: Binding(get: { revoking != nil },
                                        set: { if !$0 { revoking = nil } })) {
                Button("Annulla", role: .cancel) { revoking = nil }
                Button("Togli l'accesso", role: .destructive) {
                    if let revoking { try? profile.revoke(revoking) }
                    revoking = nil
                    Feedback.tap()
                }
            } message: {
                Text("Smette di vedere schede e recap. Le schede che ti ha scritto restano tue.")
            }
        }
    }

    private func trainerRow(_ trainer: UserAccount) -> some View {
        let accent = Color(hex: "#f59e0b")
        return Panel(padding: 13, radius: Theme.rLg) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(trainer.displayName.isEmpty ? "Il tuo trainer" : trainer.displayName)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("ti segue")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 8)

                Button {
                    revoking = profile.linkBetween(trainer: trainer.id, client: account.id)
                } label: {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Togli l'accesso a \(trainer.displayName)")
            }
        }
    }
}

/// I clienti seguiti, con l'aggiunta tramite codice.
/// Un trainer con trenta clienti non può avere trenta pannelli in colonna
/// dentro le impostazioni: si cerca per nome, si vede quanti sono, e le azioni
/// su una persona stanno tutte nella sua scheda invece che sparse nella riga.
struct ClientsSection: View {
    let trainer: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @State private var showAdd = false
    @State private var search = ""
    @State private var openClient: UserAccount?
    @State private var expanded = true

    /// Sotto questa soglia cercare è più lavoro che scorrere.
    private let searchThreshold = 6

    private var clients: [UserAccount] {
        profile.clients(of: trainer).sorted { $0.displayName < $1.displayName }
    }

    private var filtered: [UserAccount] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return clients }
        return clients.filter { $0.displayName.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("I tuoi clienti")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    if !clients.isEmpty {
                        Text("\(clients.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.textDim)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 22)
                            .background(Theme.surfaceHi, in: Capsule())
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                if clients.isEmpty {
                    Text("Nessun cliente collegato. Chiedi il codice a chi vuoi seguire e aggiungilo qui.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if clients.count >= searchThreshold {
                        searchField
                    }
                    ForEach(filtered, id: \.id) { client in
                        clientRow(client)
                    }
                    if filtered.isEmpty {
                        Text("Nessun cliente con questo nome.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textFaint)
                    }
                }

                Button("＋  Aggiungi un cliente con il codice") { showAdd = true }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddClientSheet(trainer: trainer).environmentObject(profile)
        }
        .sheet(item: $openClient) { client in
            ClientSheet(trainer: trainer, client: client).environmentObject(profile)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textFaint)
            TextField("Cerca un cliente", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.text)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }

    private func clientRow(_ client: UserAccount) -> some View {
        let accent = Color(hex: client.accentHex)
        return Button {
            openClient = client
        } label: {
            HStack(spacing: 12) {
                Image(systemName: client.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(client.displayName.isEmpty ? "Cliente" : client.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                    Text(Fmt.plural(client.orderedRoutines.count, "scheda", "schede"))
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Tutto quello che si fa con un cliente, in un posto solo.
struct ClientSheet: View {
    let trainer: UserAccount
    let client: UserAccount

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevoke = false

    private var accent: Color { Color(hex: client.accentHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: client.symbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 58, height: 58)
                            .background(accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(client.displayName.isEmpty ? "Cliente" : client.displayName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(Fmt.plural(client.orderedRoutines.count, "scheda", "schede"))
                                .font(.footnote)
                                .foregroundStyle(Theme.textDim)
                        }
                    }

                    if client.orderedRoutines.isEmpty {
                        Text("Non ha ancora nessuna scheda. Puoi scrivergliela tu: dalla sezione Schede scegli “per \(client.displayName)”.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Le sue schede")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            ForEach(client.orderedRoutines, id: \.id) { routine in
                                HStack(spacing: 10) {
                                    Text(routine.emoji)
                                    Text(routine.name)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Spacer(minLength: 6)
                                    Text(Fmt.plural(routine.orderedDays.count, "giorno", "giorni"))
                                        .font(.caption)
                                        .foregroundStyle(Theme.textFaint)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMd))
                            }
                        }
                    }

                    Button("Apri il suo profilo") {
                        profile.viewAccount(client.id)
                        Feedback.tap()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle(accent: accent))
                    .frame(maxWidth: .infinity)

                    Text("Passi a guardare schede, recap e mappa dal suo punto di vista. Torni al tuo dalle stesse impostazioni.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Smetti di seguirlo") { confirmRevoke = true }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color(hex: "#fb7185"))
                }
                .padding(18)
            }
            .pageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
            }
        }
        .presentationBackground(Theme.bg)
        .alert("Smettere di seguire \(client.displayName)?", isPresented: $confirmRevoke) {
            Button("Annulla", role: .cancel) {}
            Button("Smetti di seguire", role: .destructive) {
                if let link = profile.linkBetween(trainer: trainer.id, client: client.id) {
                    try? profile.revoke(link)
                }
                Feedback.tap()
                dismiss()
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
