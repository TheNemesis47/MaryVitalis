import Combine
import Foundation
import SwiftData

/// Chi è connesso e di chi sta guardando i dati.
///
/// Sono due cose diverse e prima non lo erano: un trainer che consulta il
/// profilo di un cliente resta se stesso (`account`) mentre guarda i dati di
/// un altro (`viewedAccount`).
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var signedInAccountID: UUID?
    @Published private(set) var viewedAccountID: UUID? {
        didSet { MaryVitalisShared.activeAccountID = viewedAccountID }
    }

    /// Non privato perché l'editor delle schede vive in `RoutineEditing.swift`.
    let context: ModelContext
    /// Collegato dopo l'avvio: senza configurazione Firebase resta `nil` e
    /// l'app continua a funzionare in locale.
    var cloud: CloudSync?

    init(context: ModelContext) {
        self.context = context
        Self.backfillInviteCodes(in: context)

        let restored = SecureSessionStore.loadAccountID()
        let account = restored.flatMap { Self.account(id: $0, in: context) }
        signedInAccountID = account?.id

        let remembered = MaryVitalisShared.activeAccountID
        let visible = account.map { Self.visibleAccountIDs(for: $0, in: context) } ?? []
        viewedAccountID = remembered.flatMap { visible.contains($0) ? $0 : nil } ?? visible.first
    }

    // MARK: - Sessione

    var isSignedIn: Bool { account != nil }

    /// L'account connesso.
    var account: UserAccount? {
        signedInAccountID.flatMap { Self.account(id: $0, in: context) }
    }

    /// L'account di cui si stanno guardando schede, recap e widget.
    var viewedAccount: UserAccount? {
        viewedAccountID.flatMap { Self.account(id: $0, in: context) }
    }

    /// Tutti gli account disponibili sul dispositivo. Con la registrazione vera
    /// (fase 2) diventerà la lista dei profili locali.
    var allAccounts: [UserAccount] {
        (try? context.fetch(FetchDescriptor<UserAccount>(
            sortBy: [SortDescriptor(\.createdAt)]
        ))) ?? []
    }

    /// I profili che l'account connesso può consultare: se stesso, più i
    /// clienti assegnati se è un trainer, tutti se è admin.
    var visibleAccounts: [UserAccount] {
        guard let account else { return [] }
        let ids = Self.visibleAccountIDs(for: account, in: context)
        return allAccounts.filter { ids.contains($0.id) }
    }

    /// Le schede del profilo consultato. Non più una per persona: quante ne ha.
    var visibleRoutines: [Routine] {
        viewedAccount?.orderedRoutines ?? []
    }

    func signIn(account: UserAccount) {
        SecureSessionStore.saveAccountID(account.id)
        signedInAccountID = account.id

        let visible = Self.visibleAccountIDs(for: account, in: context)
        let remembered = MaryVitalisShared.activeAccountID
        viewedAccountID = remembered.flatMap { visible.contains($0) ? $0 : nil } ?? account.id
    }

    /// Accesso a un profilo locale protetto da password.
    func signIn(account: UserAccount, password: String) -> Bool {
        guard CredentialStore.verify(password, for: account.id) else { return false }
        signIn(account: account)
        return true
    }

    func viewAccount(_ accountID: UUID) {
        guard let account, Self.visibleAccountIDs(for: account, in: context).contains(accountID) else { return }
        viewedAccountID = accountID
    }

    func signOut() {
        SecureSessionStore.clear()
        signedInAccountID = nil
        viewedAccountID = nil
        // Live Activity e sveglia del recupero appartengono a chi è appena
        // uscito: lasciarle accese le mostrerebbe a chi entra dopo.
        WorkoutActivityManager.endOrphans()
        RestAlarm.cancel()
    }

    // MARK: - Creazione e gestione account

    enum AccountError: LocalizedError {
        case emptyName
        case shortPassword(minimum: Int)
        case emailAlreadyUsed
        case wrongCurrentPassword

        var errorDescription: String? {
            switch self {
            case .emptyName: "Serve un nome per il profilo."
            case .shortPassword(let minimum): "La password deve avere almeno \(minimum) caratteri."
            case .emailAlreadyUsed: "Esiste già un profilo con questa email."
            case .wrongCurrentPassword: "La password attuale non è corretta."
            }
        }
    }

    static let minimumPasswordLength = 8

    @discardableResult
    func register(displayName: String,
                  email: String?,
                  password: String,
                  role: UserRole = .member,
                  appleUserID: String? = nil) throws -> UserAccount {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AccountError.emptyName }

        let cleanEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cleanEmail, !cleanEmail.isEmpty, accountExists(email: cleanEmail) {
            throw AccountError.emailAlreadyUsed
        }

        // Con Sign in with Apple la password non esiste: l'identità è l'Apple ID.
        if appleUserID == nil, password.count < Self.minimumPasswordLength {
            throw AccountError.shortPassword(minimum: Self.minimumPasswordLength)
        }

        let account = UserAccount(
            displayName: name,
            email: cleanEmail?.isEmpty == true ? nil : cleanEmail,
            appleUserID: appleUserID,
            role: role,
            symbolName: role == .trainer ? "figure.strengthtraining.traditional"
                                         : "person.crop.circle.fill",
            accentHex: Self.nextAccentHex(taken: allAccounts.map(\.accentHex))
        )
        context.insert(account)

        if appleUserID == nil {
            try CredentialStore.setPassword(password, for: account.id)
        }

        try context.save()
        return account
    }

    // MARK: - Account nel cloud
    //
    // È la differenza fra un profilo che vive su un telefono e un account vero:
    // qui la password la verifica Firebase, quindi si può entrare da un
    // dispositivo che quell'account non l'ha mai visto.

    /// Registra l'account sul cloud e ne crea la copia locale.
    @discardableResult
    func registerInCloud(displayName: String,
                         email: String,
                         password: String,
                         role: UserRole = .member) async throws -> UserAccount {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AccountError.emptyName }
        guard password.count >= Self.minimumPasswordLength else {
            throw AccountError.shortPassword(minimum: Self.minimumPasswordLength)
        }

        let cloudUser = try await AuthService.signUp(email: email,
                                                     password: password,
                                                     displayName: name)

        let account = UserAccount(
            displayName: name,
            email: cloudUser.email,
            firebaseUID: cloudUser.uid,
            role: role,
            symbolName: role == .trainer ? "figure.strengthtraining.traditional"
                                         : "person.crop.circle.fill",
            accentHex: Self.nextAccentHex(taken: allAccounts.map(\.accentHex))
        )
        context.insert(account)
        try context.save()

        signIn(account: account)
        await cloud?.start(for: account)
        return account
    }

    /// Promuove un profilo locale ad account vero.
    ///
    /// È il caso dei tre profili storici: nati su un telefono solo, senza email,
    /// senza modo di esistere altrove. Da qui in poi hanno un'identità cloud e
    /// si portano dietro tutto — schede, storico, codice invito — così un
    /// trainer può finalmente seguire i clienti da un altro dispositivo.
    func linkToCloud(account: UserAccount, email: String, password: String) async throws {
        guard account.firebaseUID == nil else { return }
        guard password.count >= Self.minimumPasswordLength else {
            throw AccountError.shortPassword(minimum: Self.minimumPasswordLength)
        }

        let cloudUser = try await AuthService.signUp(email: email,
                                                     password: password,
                                                     displayName: account.displayName)
        account.firebaseUID = cloudUser.uid
        account.email = cloudUser.email
        account.mustChangePassword = false
        account.updatedAt = .now
        try context.save()

        // La password locale non serve più: adesso a verificarla è Firebase.
        CredentialStore.removeCredentials(for: account.id)

        if let cloud {
            await cloud.start(for: account)
            // Le schede esistevano solo qui: vanno portate su, altrimenti
            // rientrando da un altro dispositivo l'utente non troverebbe niente.
            for routine in account.orderedRoutines {
                await cloud.pushRoutine(routine)
            }
        }
        objectWillChange.send()
    }

    /// Accede a un account che esiste già, anche su un dispositivo che non
    /// l'ha mai visto: è il caso che con i soli profili locali era impossibile.
    @discardableResult
    func signInToCloud(email: String, password: String) async throws -> UserAccount {
        let cloudUser = try await AuthService.signIn(email: email, password: password)

        let uid = cloudUser.uid
        var descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.firebaseUID == uid })
        descriptor.fetchLimit = 1

        let account: UserAccount
        if let existing = try? context.fetch(descriptor).first {
            account = existing
        } else if let fetched = await cloud?.ensureAccount(firebaseUID: uid) {
            // Il profilo arriva da Firestore: nome, ruolo, colore e codice
            // invito sono già quelli scelti sull'altro dispositivo.
            account = fetched
        } else {
            let created = UserAccount(displayName: cloudUser.displayName ?? "Il mio profilo",
                                      email: cloudUser.email,
                                      firebaseUID: uid)
            context.insert(created)
            try context.save()
            account = created
        }

        signIn(account: account)
        await cloud?.start(for: account)
        return account
    }

    /// Accede con Apple: se è la prima volta crea il profilo, altrimenti
    /// ritrova quello già collegato a quell'Apple ID.
    /// Ritorna `true` quando il profilo è appena nato, così la UI sa se
    /// proseguire con l'onboarding della prima scheda.
    /// Accesso con Apple, passando da Firebase.
    ///
    /// Prima creava un profilo soltanto locale: il bottone prometteva di
    /// sincronizzare fra i dispositivi e non lo faceva, e quel profilo non
    /// poteva nemmeno essere seguito da un trainer. Ora l'identità è l'`uid`
    /// di Firebase, come per gli account con email e password.
    @discardableResult
    func signInWithApple(cloudUser: AuthService.CloudUser,
                         appleUserID: String) async throws -> (account: UserAccount, isNew: Bool) {
        let uid = cloudUser.uid
        var descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.firebaseUID == uid })
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.appleUserID = appleUserID
            try? context.save()
            signIn(account: existing)
            await cloud?.start(for: existing)
            return (existing, false)
        }

        // Un profilo creato con Apple da una versione precedente vive solo su
        // questo telefono: ha l'Apple ID ma non il `firebaseUID`. Senza questo
        // controllo l'accesso ne creerebbe un secondo, vuoto, e le schede
        // resterebbero nel primo — sotto gli occhi ma irraggiungibili.
        var byApple = FetchDescriptor<UserAccount>(
            predicate: #Predicate { $0.appleUserID == appleUserID }
        )
        byApple.fetchLimit = 1
        if let local = try? context.fetch(byApple).first {
            local.firebaseUID = uid
            if local.email == nil { local.email = cloudUser.email }
            local.updatedAt = .now
            try? context.save()
            signIn(account: local)

            if let cloud {
                await cloud.start(for: local)
                await cloud.pushProfile(local)
                // Le schede esistevano solo qui: da adesso hanno dove andare.
                for routine in local.orderedRoutines {
                    await cloud.pushRoutine(routine)
                }
            }
            return (local, false)
        }

        // Il profilo può esistere già sul cloud (altro dispositivo).
        if let fetched = await cloud?.ensureAccount(firebaseUID: uid) {
            fetched.appleUserID = appleUserID
            try? context.save()
            signIn(account: fetched)
            await cloud?.start(for: fetched)
            return (fetched, false)
        }

        // Apple restituisce nome ed email **solo alla primissima**
        // autorizzazione. Le volte successive manda solo l'identificativo:
        // lasciare un segnaposto tipo "Il mio profilo" sarebbe peggio che
        // chiederlo, quindi il nome resta vuoto e l'onboarding lo domanda.
        let account = UserAccount(
            displayName: cloudUser.displayName ?? "",
            email: cloudUser.email,
            appleUserID: appleUserID,
            firebaseUID: uid,
            accentHex: Self.nextAccentHex(taken: allAccounts.map(\.accentHex))
        )
        context.insert(account)
        try context.save()

        signIn(account: account)
        await cloud?.start(for: account)
        return (account, true)
    }

    /// L'utente può revocare l'accesso dalle impostazioni di iOS mentre l'app è
    /// chiusa: in quel caso la sessione non vale più.
    func validateAppleCredentialIfNeeded() async {
        guard let account, let appleUserID = account.appleUserID else { return }
        if await !AppleSignIn.isStillAuthorized(userID: appleUserID) {
            AuthService.signOut()
            signOut()
        }
    }

    func changePassword(for account: UserAccount, current: String, new: String) throws {
        if CredentialStore.hasPassword(for: account.id) {
            guard CredentialStore.verify(current, for: account.id) else {
                throw AccountError.wrongCurrentPassword
            }
        }
        guard new.count >= Self.minimumPasswordLength else {
            throw AccountError.shortPassword(minimum: Self.minimumPasswordLength)
        }
        try CredentialStore.setPassword(new, for: account.id)
        account.mustChangePassword = false
        try context.save()
    }

    /// Cancellazione completa del profilo. La linea guida App Store 5.1.1(v)
    /// pretende che un'app che permette di creare un account permetta anche di
    /// cancellarlo, e che sparisca tutto: schede, palestre, storico, progressi,
    /// legami con il trainer e credenziali nel Portachiavi.
    func deleteAccount(_ account: UserAccount) throws {
        let accountID = account.id

        let sessions = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.ownerAccountID == accountID }
        )
        for session in (try? context.fetch(sessions)) ?? [] { context.delete(session) }

        let progress = FetchDescriptor<DayProgress>(
            predicate: #Predicate { $0.ownerAccountID == accountID }
        )
        for row in (try? context.fetch(progress)) ?? [] { context.delete(row) }

        let links = FetchDescriptor<TrainerLink>(
            predicate: #Predicate {
                $0.trainerAccountID == accountID || $0.clientAccountID == accountID
            }
        )
        for link in (try? context.fetch(links)) ?? [] { context.delete(link) }

        // Schede e palestre se ne vanno con la regola di cascata del modello.
        context.delete(account)
        try context.save()

        CredentialStore.removeCredentials(for: accountID)

        if signedInAccountID == accountID {
            signOut()
        } else if viewedAccountID == accountID {
            viewedAccountID = signedInAccountID
        }
    }

    /// Cancellazione completa: prima il cloud, poi il locale, poi l'utente di
    /// Firebase. L'ordine conta — cancellando prima l'utente, il token non
    /// varrebbe più e i dati resterebbero su Firestore senza padrone.
    func deleteAccountEverywhere(_ account: UserAccount) async throws {
        // Apple lo pretende, e senza revoca il prossimo accesso con Apple
        // verrebbe letto come un ritorno: nessun nome, nessuna email, e un
        // profilo anonimo al posto di una registrazione.
        if account.appleUserID != nil {
            await AuthService.revokeAppleAccess()
        }
        if let cloud, let uid = account.firebaseUID {
            await cloud.deleteCloudData(uid: uid, inviteCode: account.inviteCode)
        }
        let wasCloudAccount = account.firebaseUID != nil
        try deleteAccount(account)
        if wasCloudAccount {
            // Se Firebase chiede un accesso recente, l'utente di Auth resta:
            // i dati però sono già spariti, che è la parte che conta.
            try? await AuthService.deleteCloudUser()
        }
        AuthService.signOut()
    }

    private func accountExists(email: String) -> Bool {
        allAccounts.contains { $0.email?.lowercased() == email }
    }

    // MARK: - Legame trainer ↔ cliente

    enum LinkError: LocalizedError {
        case notATrainer
        case invalidCode
        case unknownCode
        case cannotLinkToSelf
        case alreadyLinked

        var errorDescription: String? {
            switch self {
            case .notATrainer: "Solo un profilo trainer può seguire dei clienti."
            case .invalidCode: "Il codice deve avere \(InviteCode.length) caratteri."
            case .unknownCode: "Nessun profilo con questo codice."
            case .cannotLinkToSelf: "Non puoi aggiungere te stesso come cliente."
            case .alreadyLinked: "Questo cliente è già collegato."
            }
        }
    }

    /// Come `requestLink`, ma cerca il cliente **sul cloud**: è l'unico modo
    /// perché un trainer possa collegarsi a qualcuno che sul suo telefono non
    /// è mai esistito. Senza configurazione Firebase ricade sulla ricerca locale.
    @discardableResult
    func requestLinkInCloud(toClientWithCode rawCode: String,
                            trainer: UserAccount) async throws -> TrainerLink {
        guard let cloud, let trainerUID = trainer.firebaseUID else {
            return try requestLink(toClientWithCode: rawCode, trainer: trainer)
        }
        guard trainer.userRole == .trainer || trainer.userRole == .admin else {
            throw LinkError.notATrainer
        }

        let code = InviteCode.normalize(rawCode)
        guard InviteCode.isValid(code) else { throw LinkError.invalidCode }
        guard let clientUID = try await cloud.findUser(byInviteCode: code) else {
            throw LinkError.unknownCode
        }
        guard clientUID != trainerUID else { throw LinkError.cannotLinkToSelf }

        // Il profilo del cliente non è leggibile finché non accetta: il legame
        // locale si crea con un segnaposto, e il nome vero arriva dopo.
        let client = await cloud.ensureAccount(firebaseUID: clientUID)

        let link = TrainerLink(trainerAccountID: trainer.id,
                               clientAccountID: client?.id ?? UUID(),
                               status: .pending)
        context.insert(link)
        try context.save()

        await cloud.pushLink(link, trainerUID: trainerUID, clientUID: clientUID)
        return link
    }

    /// Il trainer digita il codice che il cliente gli ha dettato. Nasce una
    /// richiesta **in sospeso**: finché il cliente non l'accetta, il trainer non
    /// vede niente. Il consenso non è un dettaglio, sono i dati di salute di
    /// un'altra persona.
    @discardableResult
    func requestLink(toClientWithCode rawCode: String, trainer: UserAccount) throws -> TrainerLink {
        guard trainer.userRole == .trainer || trainer.userRole == .admin else {
            throw LinkError.notATrainer
        }

        let code = InviteCode.normalize(rawCode)
        guard InviteCode.isValid(code) else { throw LinkError.invalidCode }

        var descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.inviteCode == code })
        descriptor.fetchLimit = 1
        guard let client = try? context.fetch(descriptor).first else { throw LinkError.unknownCode }
        guard client.id != trainer.id else { throw LinkError.cannotLinkToSelf }

        if let existing = link(trainer: trainer.id, client: client.id) {
            guard existing.linkStatus == .revoked else { throw LinkError.alreadyLinked }
            existing.linkStatus = .pending
            try context.save()
            return existing
        }

        let link = TrainerLink(trainerAccountID: trainer.id,
                               clientAccountID: client.id,
                               status: .pending)
        context.insert(link)
        try context.save()
        return link
    }

    /// Le richieste che aspettano una risposta dal profilo consultato.
    func pendingRequests(for account: UserAccount) -> [TrainerLink] {
        let clientID = account.id
        let descriptor = FetchDescriptor<TrainerLink>(
            predicate: #Predicate { $0.clientAccountID == clientID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.linkStatus == .pending }
    }

    /// I clienti accettati di un trainer. È una relazione molti-a-uno: un
    /// trainer segue quanti clienti vuole, un cliente ha un trainer per volta
    /// solo se decide così — niente lo vieta a livello di modello.
    func clients(of trainer: UserAccount) -> [UserAccount] {
        let trainerID = trainer.id
        let descriptor = FetchDescriptor<TrainerLink>(
            predicate: #Predicate { $0.trainerAccountID == trainerID }
        )
        let accepted = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.linkStatus == .accepted }
            .map(\.clientAccountID)
        return allAccounts.filter { accepted.contains($0.id) }
    }

    /// I trainer che seguono questo profilo.
    func trainers(of client: UserAccount) -> [UserAccount] {
        let clientID = client.id
        let descriptor = FetchDescriptor<TrainerLink>(
            predicate: #Predicate { $0.clientAccountID == clientID }
        )
        let accepted = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.linkStatus == .accepted }
            .map(\.trainerAccountID)
        return allAccounts.filter { accepted.contains($0.id) }
    }

    func account(id: UUID) -> UserAccount? {
        Self.account(id: id, in: context)
    }

    func respond(to link: TrainerLink, accept: Bool) throws {
        link.linkStatus = accept ? .accepted : .revoked
        try context.save()
        objectWillChange.send()
        pushLinkToCloud(link)
    }

    /// Revoca, esercitabile da entrambe le parti: il cliente smette di essere
    /// seguito, il trainer smette di seguire.
    func revoke(_ link: TrainerLink) throws {
        link.linkStatus = .revoked
        try context.save()
        objectWillChange.send()
        pushLinkToCloud(link)
    }

    /// Senza questo, l'accettazione del cliente resterebbe sul suo telefono e
    /// il trainer non vedrebbe mai comparire il cliente.
    private func pushLinkToCloud(_ link: TrainerLink) {
        guard let cloud,
              let trainerUID = account(id: link.trainerAccountID)?.firebaseUID,
              let clientUID = account(id: link.clientAccountID)?.firebaseUID else { return }
        Task { await cloud.pushLink(link, trainerUID: trainerUID, clientUID: clientUID) }
    }

    /// Rigenera il codice: serve a chi l'ha dettato alla persona sbagliata.
    /// I collegamenti già accettati restano, il vecchio codice smette di valere.
    func regenerateInviteCode(for account: UserAccount) throws {
        let old = account.inviteCode
        account.inviteCode = InviteCode.generate()
        account.updatedAt = .now
        try context.save()
        objectWillChange.send()

        if let cloud {
            Task {
                await cloud.releaseInviteCode(old)
                await cloud.pushProfile(account)
            }
        }
    }

    func linkBetween(trainer: UUID, client: UUID) -> TrainerLink? {
        link(trainer: trainer, client: client)
    }

    private func link(trainer: UUID, client: UUID) -> TrainerLink? {
        var descriptor = FetchDescriptor<TrainerLink>(
            predicate: #Predicate {
                $0.trainerAccountID == trainer && $0.clientAccountID == client
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Colori di profilo distinti, così due persone sullo stesso telefono non
    /// si confondono nel calendario e nei widget.
    private static let accentPalette = [
        "#38bdf8", "#fb7185", "#a78bfa", "#4ade80", "#fbbf24", "#f472b6", "#22d3ee"
    ]

    private static func nextAccentHex(taken: [String]) -> String {
        accentPalette.first { !taken.contains($0) } ?? accentPalette[taken.count % accentPalette.count]
    }

    // MARK: - Interrogazioni

    /// I profili creati prima dei codici invito ne hanno uno vuoto: gliene
    /// assegna uno al primo avvio utile.
    private static func backfillInviteCodes(in context: ModelContext) {
        let descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.inviteCode == "" })
        let missing = (try? context.fetch(descriptor)) ?? []
        guard !missing.isEmpty else { return }
        for account in missing {
            account.inviteCode = InviteCode.generate()
        }
        try? context.save()
    }

    private static func account(id: UUID, in context: ModelContext) -> UserAccount? {
        var descriptor = FetchDescriptor<UserAccount>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func visibleAccountIDs(for account: UserAccount, in context: ModelContext) -> [UUID] {
        switch account.userRole {
        case .member:
            return [account.id]

        case .trainer:
            let trainerID = account.id
            let descriptor = FetchDescriptor<TrainerLink>(
                predicate: #Predicate { $0.trainerAccountID == trainerID }
            )
            let links = (try? context.fetch(descriptor)) ?? []
            let clients = links
                .filter { $0.linkStatus == .accepted }
                .map(\.clientAccountID)
            return [account.id] + clients.filter { $0 != account.id }

        case .admin:
            let all = (try? context.fetch(FetchDescriptor<UserAccount>())) ?? []
            return all.map(\.id)
        }
    }
}
