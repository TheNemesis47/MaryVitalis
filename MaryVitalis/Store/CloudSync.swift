import FirebaseFirestore
import Foundation
import SwiftData

/// Sincronizza SwiftData con Firestore.
///
/// Regole che si è dato:
/// - **SwiftData è quello che la UI legge.** Firestore non blocca mai una
///   schermata: in palestra il telefono spesso non prende.
/// - **Una scheda è un documento solo**, con giorni ed esercizi annidati. Si
///   legge sempre intera, pesa pochi kilobyte, e la modifica del trainer arriva
///   al cliente tutta insieme invece che a pezzi.
/// - **Vince chi ha scritto per ultimo**, confrontando `updatedAt`. Con un
///   trainer e i suoi clienti le modifiche in contemporanea sulla stessa scheda
///   sono rare; quando capiterà servirà qualcosa di più fine.
@MainActor
final class CloudSync: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?

    private let context: ModelContext
    private var listeners: [ListenerRegistration] = []

    init(context: ModelContext) {
        self.context = context
    }

    deinit {
        listeners.forEach { $0.remove() }
    }

    // MARK: - Ciclo di vita

    /// Da chiamare dopo l'accesso: allinea il profilo, poi resta in ascolto.
    func start(for account: UserAccount) async {
        guard FirebaseService.isConfigured, let uid = account.firebaseUID else { return }
        stop()
        await pushProfile(account)
        await pullEverything(uid: uid)
        observe(uid: uid)
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    // MARK: - Profilo e codice invito

    func pushProfile(_ account: UserAccount) async {
        guard let uid = account.firebaseUID else { return }
        do {
            try await FirebaseService.db.collection(FirestorePath.users).document(uid).setData([
                "displayName": account.displayName,
                "email": account.email as Any,
                "role": account.role,
                "symbolName": account.symbolName,
                "accentHex": account.accentHex,
                "inviteCode": account.inviteCode,
                "updatedAt": Timestamp(date: account.updatedAt)
            ], merge: true)

            // Il codice vive fuori dal profilo: per collegarsi bisogna poterlo
            // cercare, e non si vuole rendere leggibile tutto il profilo a
            // chiunque tiri a indovinare un codice.
            try await FirebaseService.db.collection(FirestorePath.inviteCodes)
                .document(account.inviteCode)
                .setData(["userId": uid])
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Cancella il vecchio documento del codice quando l'utente lo rigenera,
    /// altrimenti resterebbe a puntare a lui per sempre.
    func releaseInviteCode(_ code: String) async {
        guard FirebaseService.isConfigured, !code.isEmpty else { return }
        try? await FirebaseService.db.collection(FirestorePath.inviteCodes)
            .document(code).delete()
    }

    // MARK: - Legame trainer ↔ cliente

    /// Cerca chi ha quel codice. Restituisce solo l'identificativo: chi conosce
    /// il codice scopre che esiste qualcuno, non chi è.
    func findUser(byInviteCode code: String) async throws -> String? {
        let snapshot = try await FirebaseService.db
            .collection(FirestorePath.inviteCodes).document(code).getDocument()
        return snapshot.data()?["userId"] as? String
    }

    func pushLink(_ link: TrainerLink, trainerUID: String, clientUID: String) async {
        let id = FirestorePath.linkID(trainer: trainerUID, client: clientUID)
        do {
            try await FirebaseService.db.collection(FirestorePath.trainerLinks)
                .document(id).setData([
                    "trainerId": trainerUID,
                    "clientId": clientUID,
                    "status": link.status,
                    "createdAt": Timestamp(date: link.createdAt),
                    "localID": link.id.uuidString
                ], merge: true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Schede

    func pushRoutine(_ routine: Routine) async {
        guard FirebaseService.isConfigured,
              let ownerUID = routine.owner?.firebaseUID else { return }
        do {
            try await FirebaseService.db.collection(FirestorePath.routines)
                .document(routine.id.uuidString)
                .setData(RoutinePayload(routine: routine, ownerUID: ownerUID).dictionary,
                         merge: false)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteRoutine(id: UUID) async {
        guard FirebaseService.isConfigured else { return }
        try? await FirebaseService.db.collection(FirestorePath.routines)
            .document(id.uuidString).delete()
    }

    // MARK: - Cancellazione

    /// Cancella dal cloud tutto quello che appartiene a un profilo.
    ///
    /// Va fatto **prima** di eliminare l'utente da Firebase Auth: dopo, il token
    /// non vale più e le regole rifiuterebbero ogni scrittura, lasciando i dati
    /// lì per sempre senza che nessuno possa più toccarli. È anche quello che
    /// pretende la linea guida App Store 5.1.1(v): cancellare l'account
    /// significa cancellare i dati, non solo disconnettersi.
    func deleteCloudData(uid: String, inviteCode: String) async {
        guard FirebaseService.isConfigured else { return }
        let db = FirebaseService.db

        for collection in [FirestorePath.routines, FirestorePath.sessions,
                           FirestorePath.progress, FirestorePath.gyms] {
            if let documents = try? await db.collection(collection)
                .whereField("ownerId", isEqualTo: uid).getDocuments() {
                for document in documents.documents {
                    try? await document.reference.delete()
                }
            }
        }

        for field in ["clientId", "trainerId"] {
            if let links = try? await db.collection(FirestorePath.trainerLinks)
                .whereField(field, isEqualTo: uid).getDocuments() {
                for document in links.documents {
                    try? await document.reference.delete()
                }
            }
        }

        // Il codice torna disponibile: se restasse, resterebbe a puntare a un
        // profilo che non esiste più e nessuno potrebbe più riprenderselo.
        if !inviteCode.isEmpty {
            try? await db.collection(FirestorePath.inviteCodes).document(inviteCode).delete()
        }

        try? await db.collection(FirestorePath.users).document(uid).delete()
    }

    // MARK: - Lettura

    private func pullEverything(uid: String) async {
        isSyncing = true
        defer { isSyncing = false; lastSync = Date() }

        await pullLinks(uid: uid)
        await pullRoutines(ownedBy: uid)

        // Le schede dei clienti seguiti: è il motivo per cui esiste tutto questo.
        for clientUID in acceptedClientUIDs(trainerUID: uid) {
            await pullRoutines(ownedBy: clientUID)
        }
    }

    private func pullLinks(uid: String) async {
        do {
            let asClient = try await FirebaseService.db.collection(FirestorePath.trainerLinks)
                .whereField("clientId", isEqualTo: uid).getDocuments()
            let asTrainer = try await FirebaseService.db.collection(FirestorePath.trainerLinks)
                .whereField("trainerId", isEqualTo: uid).getDocuments()

            for document in asClient.documents + asTrainer.documents {
                await applyLink(document.data())
            }
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func pullRoutines(ownedBy uid: String) async {
        do {
            let snapshot = try await FirebaseService.db.collection(FirestorePath.routines)
                .whereField("ownerId", isEqualTo: uid).getDocuments()
            for document in snapshot.documents {
                await applyRoutine(document.data())
            }
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Ascolto

    private func observe(uid: String) {
        let links = FirebaseService.db.collection(FirestorePath.trainerLinks)
            .whereField("clientId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    for document in snapshot.documents {
                        await self.applyLink(document.data())
                    }
                    try? self.context.save()
                }
            }

        // Le proprie schede: se il trainer le modifica, arrivano qui.
        let routines = FirebaseService.db.collection(FirestorePath.routines)
            .whereField("ownerId", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    for document in snapshot.documents {
                        await self.applyRoutine(document.data())
                    }
                    try? self.context.save()
                    self.lastSync = Date()
                }
            }

        listeners = [links, routines]
    }

    // MARK: - Applicazione in locale

    /// Recupera il profilo di qualcuno che su questo dispositivo non esiste —
    /// il cliente appena collegato, o il trainer che ha mandato la richiesta —
    /// e ne crea una copia locale. Se le regole non concedono la lettura
    /// (legame non ancora accettato) non succede niente: è il comportamento
    /// voluto, il nome altrui non si vede prima del consenso.
    @discardableResult
    func ensureAccount(firebaseUID uid: String) async -> UserAccount? {
        if let existing = account(firebaseUID: uid) { return existing }
        guard let data = try? await FirebaseService.db
            .collection(FirestorePath.users).document(uid).getDocument().data() else { return nil }

        let account = UserAccount(
            displayName: data["displayName"] as? String ?? "Profilo",
            email: data["email"] as? String,
            firebaseUID: uid,
            role: UserRole(rawValue: data["role"] as? String ?? "") ?? .member,
            symbolName: data["symbolName"] as? String ?? "person.crop.circle.fill",
            accentHex: data["accentHex"] as? String ?? "#38bdf8",
            inviteCode: data["inviteCode"] as? String ?? InviteCode.generate()
        )
        context.insert(account)
        try? context.save()
        return account
    }

    private func applyLink(_ data: [String: Any]) async {
        guard let trainerUID = data["trainerId"] as? String,
              let clientUID = data["clientId"] as? String,
              let status = data["status"] as? String else { return }

        // Le due parti possono non esistere ancora in locale: il trainer non ha
        // mai visto il cliente, e viceversa.
        let trainer = await ensureAccount(firebaseUID: trainerUID)
        let client = await ensureAccount(firebaseUID: clientUID)
        guard let trainer, let client else { return }

        let trainerID = trainer.id
        let clientID = client.id
        var descriptor = FetchDescriptor<TrainerLink>(
            predicate: #Predicate {
                $0.trainerAccountID == trainerID && $0.clientAccountID == clientID
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            existing.status = status
        } else {
            context.insert(TrainerLink(
                trainerAccountID: trainerID,
                clientAccountID: clientID,
                status: LinkStatus(rawValue: status) ?? .pending
            ))
        }
    }

    private func applyRoutine(_ data: [String: Any]) async {
        guard let payload = RoutinePayload(dictionary: data),
              let owner = await ensureAccount(firebaseUID: payload.ownerUID) else { return }

        let routineID = payload.id
        var descriptor = FetchDescriptor<Routine>(predicate: #Predicate { $0.id == routineID })
        descriptor.fetchLimit = 1
        let existing = try? context.fetch(descriptor).first

        // Vince chi ha scritto per ultimo. Se la copia locale è più recente,
        // quella remota si ignora: la si sovrascriverà alla prossima scrittura.
        if let existing, existing.updatedAt >= payload.updatedAt { return }

        let routine = existing ?? {
            let created = Routine(id: routineID)
            context.insert(created)
            return created
        }()

        payload.apply(to: routine, owner: owner, context: context)
    }

    private func account(firebaseUID: String) -> UserAccount? {
        var descriptor = FetchDescriptor<UserAccount>(
            predicate: #Predicate { $0.firebaseUID == firebaseUID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func acceptedClientUIDs(trainerUID: String) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<TrainerLink>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<UserAccount>())) ?? []
        let byID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        return all.compactMap { link in
            guard link.linkStatus == .accepted,
                  byID[link.trainerAccountID]?.firebaseUID == trainerUID,
                  let clientUID = byID[link.clientAccountID]?.firebaseUID else { return nil }
            return clientUID
        }
    }
}

/// Una scheda intera nel formato di Firestore: dizionari annidati, niente
/// sottocollezioni. Sta comodamente sotto il limite di 1 MiB per documento.
struct RoutinePayload {
    let id: UUID
    let ownerUID: String
    let updatedAt: Date
    let dictionary: [String: Any]

    init(routine: Routine, ownerUID: String) {
        id = routine.id
        self.ownerUID = ownerUID
        updatedAt = routine.updatedAt

        dictionary = [
            "id": routine.id.uuidString,
            "ownerId": ownerUID,
            "authorId": routine.authorAccountID?.uuidString as Any,
            "name": routine.name,
            "emoji": routine.emoji,
            "accentHex": routine.accentHex,
            "goal": routine.goal,
            "summary": routine.summary,
            "meta": routine.meta,
            "isTemplate": routine.isTemplate,
            "sortIndex": routine.sortIndex,
            "updatedAt": Timestamp(date: routine.updatedAt),
            "days": routine.orderedDays.map { day in
                [
                    "id": day.id.uuidString,
                    "name": day.name,
                    "sortIndex": day.sortIndex,
                    "preferredWeekday": day.preferredWeekday as Any,
                    "items": day.orderedItems.map { item in
                        [
                            "id": item.id.uuidString,
                            "exerciseQuery": item.exerciseQuery,
                            "exerciseName": item.exerciseName,
                            "sets": item.sets,
                            "repsText": item.repsText as Any,
                            "minutes": item.minutes as Any,
                            "note": item.note as Any,
                            "restOverrideSeconds": item.restOverrideSeconds as Any,
                            "sortIndex": item.sortIndex,
                            "rawDetails": item.rawDetails as Any
                        ] as [String: Any]
                    }
                ] as [String: Any]
            }
        ]
    }

    init?(dictionary: [String: Any]) {
        guard let rawID = dictionary["id"] as? String,
              let id = UUID(uuidString: rawID),
              let ownerUID = dictionary["ownerId"] as? String else { return nil }
        self.id = id
        self.ownerUID = ownerUID
        updatedAt = (dictionary["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        self.dictionary = dictionary
    }

    /// Riscrive giorni ed esercizi da zero. È volutamente brutale: una scheda è
    /// piccola, e ricostruirla evita tutta la classe di bug in cui un esercizio
    /// cancellato dal trainer sopravvive sul telefono del cliente.
    @MainActor
    func apply(to routine: Routine, owner: UserAccount, context: ModelContext) {
        routine.owner = owner
        routine.name = dictionary["name"] as? String ?? ""
        routine.emoji = dictionary["emoji"] as? String ?? "💪"
        routine.accentHex = dictionary["accentHex"] as? String ?? "#38bdf8"
        routine.goal = dictionary["goal"] as? String ?? ""
        routine.summary = dictionary["summary"] as? String ?? ""
        routine.meta = dictionary["meta"] as? [String] ?? []
        routine.isTemplate = dictionary["isTemplate"] as? Bool ?? false
        routine.sortIndex = dictionary["sortIndex"] as? Int ?? 0
        routine.updatedAt = updatedAt
        if let author = dictionary["authorId"] as? String {
            routine.authorAccountID = UUID(uuidString: author)
        }

        for day in routine.days ?? [] {
            context.delete(day)
        }
        routine.days = []

        for rawDay in dictionary["days"] as? [[String: Any]] ?? [] {
            let day = RoutineDay(
                id: UUID(uuidString: rawDay["id"] as? String ?? "") ?? UUID(),
                name: rawDay["name"] as? String ?? "",
                sortIndex: rawDay["sortIndex"] as? Int ?? 0,
                preferredWeekday: rawDay["preferredWeekday"] as? Int
            )
            day.routine = routine
            context.insert(day)

            for rawItem in rawDay["items"] as? [[String: Any]] ?? [] {
                let item = RoutineItem(
                    id: UUID(uuidString: rawItem["id"] as? String ?? "") ?? UUID(),
                    exerciseQuery: rawItem["exerciseQuery"] as? String ?? "",
                    exerciseName: rawItem["exerciseName"] as? String ?? "",
                    sets: rawItem["sets"] as? Int ?? 1,
                    repsText: rawItem["repsText"] as? String,
                    minutes: rawItem["minutes"] as? Int,
                    note: rawItem["note"] as? String,
                    restOverrideSeconds: rawItem["restOverrideSeconds"] as? Int,
                    sortIndex: rawItem["sortIndex"] as? Int ?? 0,
                    rawDetails: rawItem["rawDetails"] as? String
                )
                item.day = day
                context.insert(item)
            }
        }
    }
}
