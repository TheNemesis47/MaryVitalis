import Foundation
import SwiftData
import SwiftUI

// Sostituti dei soli tipi che non compilano fuori da iOS (ActivityKit, WidgetKit).
// Tutto il resto è il codice di produzione vero, compilato così com'è.
enum MaryVitalisShared {
    nonisolated(unsafe) static var activeAccountID: UUID?
    nonisolated(unsafe) static var legacySelectedUserID: String?
}

enum WorkoutStore {
    static let defaultRest = 90
}

// Firebase non compila fuori da iOS: qui il cloud è assente, che è anche il
// caso da verificare — l'app deve funzionare in locale senza configurazione.
enum FirebaseService {
    static let isConfigured = false
}

enum AuthService {
    struct CloudUser {
        let uid: String
        var email: String? = nil
        let displayName: String?
        init(uid: String, fullName: String? = nil, email: String? = nil, displayName: String?) {
            self.uid = uid
            self.email = email
            self.displayName = displayName
        }
    }
    static func signUp(email: String, password: String, displayName: String) async throws -> CloudUser {
        CloudUser(uid: UUID().uuidString, email: email, displayName: displayName)
    }
    static func signIn(email: String, password: String) async throws -> CloudUser {
        CloudUser(uid: UUID().uuidString, email: email, displayName: nil)
    }
    static func deleteCloudUser() async throws {}
    static func signOut() {}
    static func revokeAppleAccess() async {}
}

@MainActor
final class CloudSync {
    func start(for account: UserAccount) async {}
    func pushProfile(_ account: UserAccount) async {}
    func releaseInviteCode(_ code: String) async {}
    func findUser(byInviteCode code: String) async throws -> String? { nil }
    func pushLink(_ link: TrainerLink, trainerUID: String, clientUID: String) async {}
    func ensureAccount(firebaseUID uid: String) async -> UserAccount? { nil }
    func deleteCloudData(uid: String, inviteCode: String) async {}
    func pushRoutine(_ routine: Routine) async {}
    func deleteRoutine(id: UUID) async {}
}

extension Color {
    init(hex: String) { self = .blue }
}

// MARK: - Banco di prova

var passed = 0
var failed = 0

func check(_ name: String, _ condition: Bool) {
    if condition { passed += 1; print("  OK   \(name)") }
    else { failed += 1; print("  FAIL \(name)") }
}

@MainActor
func run() async throws {



    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: UserAccount.self, TrainerLink.self, Routine.self, RoutineDay.self,
        RoutineItem.self, WorkoutSession.self, DayProgress.self,
        Gym.self, GymZone.self, GymEquipment.self, ExerciseEquipmentLink.self,
        configurations: configuration
    )
    let context = container.mainContext
    let profile = ProfileStore(context: context)

    print("\n[registrazione]")
    let anna = try profile.register(displayName: "Anna", email: "Anna@Esempio.IT ",
                                    password: "unapassword", role: .member)
    check("account creato", anna.displayName == "Anna")
    check("email normalizzata", anna.email == "anna@esempio.it")
    check("password nel Portachiavi", CredentialStore.hasPassword(for: anna.id))
    check("verifica password giusta", CredentialStore.verify("unapassword", for: anna.id))
    check("rifiuta password sbagliata", !CredentialStore.verify("altrapassword", for: anna.id))

    print("\n[validazione]")
    check("nome vuoto rifiutato", (try? profile.register(displayName: "   ", email: nil,
                                                         password: "unapassword")) == nil)
    check("password corta rifiutata", (try? profile.register(displayName: "Bea", email: nil,
                                                              password: "corta")) == nil)
    check("email duplicata rifiutata", (try? profile.register(displayName: "Bis",
                                                               email: "anna@esempio.it",
                                                               password: "unapassword")) == nil)

    print("\n[colori distinti]")
    let bea = try profile.register(displayName: "Bea", email: nil, password: "unapassword")
    check("accento diverso da Anna", bea.accentHex != anna.accentHex)

    print("\n[accesso]")
    check("accesso con password giusta", profile.signIn(account: anna, password: "unapassword"))
    check("accesso con password sbagliata negato", !profile.signIn(account: bea, password: "xxxxxxxx"))
    check("connesso è Anna", profile.account?.id == anna.id)

    print("\n[cambio password]")
    check("password attuale sbagliata rifiutata",
          (try? profile.changePassword(for: anna, current: "nonquesta", new: "nuovapassword")) == nil)
    try profile.changePassword(for: anna, current: "unapassword", new: "nuovapassword")
    check("nuova password valida", CredentialStore.verify("nuovapassword", for: anna.id))
    check("vecchia password non vale più", !CredentialStore.verify("unapassword", for: anna.id))
    check("mustChangePassword azzerato", anna.mustChangePassword == false)
    check("nuova password corta rifiutata",
          (try? profile.changePassword(for: anna, current: "nuovapassword", new: "corta")) == nil)

    print("\n[Sign in with Apple]")
    let appleUser = AuthService.CloudUser(uid: "firebase-apple-001",
                                          fullName: nil,
                                          displayName: "Carlo Verdi")
    let first = try await profile.signInWithApple(cloudUser: appleUser, appleUserID: "apple-001")
    check("profilo Apple creato", first.isNew)
    check("nome preso da Apple", first.account.displayName == "Carlo Verdi")
    check("identita cloud collegata", first.account.firebaseUID == "firebase-apple-001")
    check("nessuna password per l'account Apple", !CredentialStore.hasPassword(for: first.account.id))

    let second = try await profile.signInWithApple(cloudUser: appleUser, appleUserID: "apple-001")
    check("secondo accesso ritrova lo stesso profilo",
          !second.isNew && second.account.id == first.account.id)

    // Apple manda il nome solo la primissima volta: senza, il profilo nasce
    // senza nome e l'onboarding lo chiede, invece di inventarne uno.
    let senzaNome = AuthService.CloudUser(uid: "firebase-apple-002",
                                          fullName: nil, displayName: nil)
    let terzo = try await profile.signInWithApple(cloudUser: senzaNome, appleUserID: "apple-002")
    check("senza nome da Apple il profilo resta da nominare",
          terzo.isNew && terzo.account.displayName.isEmpty)

    print("\n[scheda di partenza]")
    let seed = RoutineFactory.starterTemplates[0]
    RoutineFactory.insert(seed: seed, named: RoutineFactory.templateName(for: seed),
                          owner: anna, into: context)
    try context.save()
    check("scheda con il nome dell'obiettivo", anna.orderedRoutines.first?.name == seed.goal)
    check("giorni creati", anna.orderedRoutines.first?.orderedDays.count == seed.days.count)
    check("esercizi creati",
          anna.orderedRoutines.first?.totalExercises == seed.days.reduce(0) { $0 + $1.exercises.count })
    check("testo originale conservato",
          anna.orderedRoutines.first?.orderedDays.first?.orderedItems.first?.details
            == seed.days[0].exercises[0].details)

    print("\n[codice invito]")
    check("codice generato", InviteCode.isValid(anna.inviteCode))
    check("codici distinti", anna.inviteCode != bea.inviteCode)
    check("alfabeto senza caratteri ambigui",
          !anna.inviteCode.contains(where: { "01ILO".contains($0) }))
    check("normalizza minuscole e trattini",
          InviteCode.normalize(" k7m-2qx ") == "K7M2QX")
    check("formattazione a metà", InviteCode.formatted("K7M2QX") == "K7M-2QX")

    print("\n[legame trainer ↔ cliente]")
    let coach = try profile.register(displayName: "Coach", email: "coach@esempio.it",
                                     password: "unapassword", role: .trainer)
    check("un utente normale non può collegare clienti",
          (try? profile.requestLink(toClientWithCode: anna.inviteCode, trainer: bea)) == nil)
    check("codice inesistente rifiutato",
          (try? profile.requestLink(toClientWithCode: "ZZZZZZ", trainer: coach)) == nil)
    check("codice malformato rifiutato",
          (try? profile.requestLink(toClientWithCode: "ABC", trainer: coach)) == nil)
    check("non ci si collega a se stessi",
          (try? profile.requestLink(toClientWithCode: coach.inviteCode, trainer: coach)) == nil)

    let request = try profile.requestLink(toClientWithCode: anna.inviteCode, trainer: coach)
    check("richiesta creata in sospeso", request.linkStatus == .pending)
    check("il cliente vede la richiesta",
          profile.pendingRequests(for: anna).contains { $0.id == request.id })
    check("senza consenso il trainer non vede il cliente",
          profile.clients(of: coach).isEmpty)
    check("richiesta doppia rifiutata",
          (try? profile.requestLink(toClientWithCode: anna.inviteCode, trainer: coach)) == nil)

    try profile.respond(to: request, accept: true)
    check("dopo il consenso il cliente compare",
          profile.clients(of: coach).contains { $0.id == anna.id })
    check("il cliente vede il suo trainer",
          profile.trainers(of: anna).contains { $0.id == coach.id })
    check("nessuna richiesta in sospeso", profile.pendingRequests(for: anna).isEmpty)

    print("\n[molti clienti per un trainer]")
    let beaLink = try profile.requestLink(toClientWithCode: bea.inviteCode, trainer: coach)
    try profile.respond(to: beaLink, accept: true)
    check("due clienti collegati", profile.clients(of: coach).count == 2)

    print("\n[visibilità del trainer]")
    profile.signIn(account: coach)
    let visible = profile.visibleAccounts.map(\.id)
    check("il trainer vede sé e i due clienti", visible.count == 3)
    check("vede Anna", visible.contains(anna.id))
    profile.viewAccount(anna.id)
    check("può consultare il profilo di Anna", profile.viewedAccountID == anna.id)

    print("\n[revoca]")
    try profile.revoke(beaLink)
    check("cliente revocato sparisce", !profile.clients(of: coach).contains { $0.id == bea.id })
    check("l'altro cliente resta", profile.clients(of: coach).contains { $0.id == anna.id })
    profile.signIn(account: coach)
    check("il revocato esce dalla visibilità", !profile.visibleAccounts.contains { $0.id == bea.id })
    let again = try profile.requestLink(toClientWithCode: bea.inviteCode, trainer: coach)
    check("dopo la revoca si può richiedere di nuovo", again.linkStatus == .pending)

    print("\n[rigenerazione del codice]")
    let oldCode = anna.inviteCode
    try profile.regenerateInviteCode(for: anna)
    check("codice cambiato", anna.inviteCode != oldCode)
    check("il vecchio codice non vale più",
          (try? profile.requestLink(toClientWithCode: oldCode, trainer: coach)) == nil)
    check("i collegamenti già accettati restano",
          profile.clients(of: coach).contains { $0.id == anna.id })

    print("\n[editor: creazione]")
    let nuova = profile.createRoutine(named: "Prova", for: anna, dayCount: 3)
    check("scheda creata con 3 giorni", nuova.orderedDays.count == 3)
    check("proprietario corretto", nuova.owner?.id == anna.id)
    check("giorni numerati in ordine",
          nuova.orderedDays.map(\.sortIndex) == [0, 1, 2])

    print("\n[editor: giorni]")
    profile.addDay(to: nuova)
    check("giorno aggiunto in fondo", nuova.orderedDays.count == 4)
    check("indice del nuovo giorno", nuova.orderedDays.last?.sortIndex == 3)
    profile.moveDays(in: nuova, from: IndexSet(integer: 0), to: 4)
    check("giorni riordinati", nuova.orderedDays.first?.name == "Giorno 2")
    let daDeleteName = nuova.orderedDays[1].name
    profile.delete(nuova.orderedDays[1])
    check("giorno eliminato", nuova.orderedDays.count == 3)
    check("indici ricompattati", nuova.orderedDays.map(\.sortIndex) == [0, 1, 2])
    check("eliminato quello giusto", !nuova.orderedDays.contains { $0.name == daDeleteName })

    print("\n[editor: esercizi]")
    let primoGiorno = nuova.orderedDays[0]
    profile.addItem(to: primoGiorno, query: "lever chest press", name: "Chest press")
    profile.addItem(to: primoGiorno, query: "lever seated row", name: "Seated row")
    profile.addItem(to: primoGiorno, query: "lever leg extension", name: "Leg extension")
    check("tre esercizi aggiunti", primoGiorno.orderedItems.count == 3)
    check("valori di partenza sensati",
          primoGiorno.orderedItems[0].sets == 3 && primoGiorno.orderedItems[0].repsText == "12")
    check("riga generata leggibile",
          primoGiorno.orderedItems[0].details == "3 serie x 12 ripetizioni")

    profile.moveItems(in: primoGiorno, from: IndexSet(integer: 2), to: 0)
    check("esercizi riordinati",
          primoGiorno.orderedItems.first?.exerciseName == "Leg extension")
    profile.delete(primoGiorno.orderedItems[1])
    check("esercizio eliminato", primoGiorno.orderedItems.count == 2)
    check("indici ricompattati", primoGiorno.orderedItems.map(\.sortIndex) == [0, 1])

    print("\n[editor: blocco cardio]")
    let cardio = profile.addItem(to: primoGiorno, query: "stationary bike run",
                                 name: "Cyclette", sets: 1, reps: nil, minutes: 20)
    check("riconosciuto come cardio", cardio.isCardio)
    check("riga cardio leggibile", cardio.details == "20 min")

    print("\n[editor: duplicazione]")
    let copia = profile.duplicate(nuova)
    check("copia con nome distinto", copia.name == "Prova (copia)")
    check("stessi giorni", copia.orderedDays.count == nuova.orderedDays.count)
    check("stessi esercizi",
          copia.orderedDays[0].orderedItems.count == primoGiorno.orderedItems.count)
    copia.orderedDays[0].orderedItems[0].sets = 99
    check("copia indipendente dall'originale",
          primoGiorno.orderedItems[0].sets != 99)

    print("\n[editor: il trainer scrive per il cliente]")
    profile.signIn(account: coach)
    let perAnna = profile.createRoutine(named: "Scheda di Anna", for: anna)
    check("la scheda è del cliente", perAnna.owner?.id == anna.id)
    check("l'autore è il trainer", perAnna.authorAccountID == coach.id)
    check("compare fra le schede del cliente",
          anna.orderedRoutines.contains { $0.id == perAnna.id })

    print("\n[editor: eliminazione]")
    let daEliminare = perAnna.id
    profile.delete(perAnna)
    check("scheda eliminata",
          !anna.orderedRoutines.contains { $0.id == daEliminare })
    profile.delete(copia)
    profile.delete(nuova)
    profile.signIn(account: anna)

    print("\n[cancellazione account]")
    let routineID = anna.orderedRoutines.first!.id
    let dayID = anna.orderedRoutines.first!.orderedDays.first!.id
    let itemID = anna.orderedRoutines.first!.orderedDays.first!.orderedItems.first!.id
    context.insert(DayProgress(ownerAccountID: anna.id, routineID: routineID,
                               dayID: dayID, itemID: itemID, completedSets: 2))
    context.insert(WorkoutSession(ownerAccountID: anna.id, routineID: routineID,
                                  routineName: "x", dateKey: "2026-08-01"))
    context.insert(TrainerLink(trainerAccountID: bea.id, clientAccountID: anna.id))
    try context.save()

    let annaID = anna.id
    // Il caso che conta: si cancella il profilo con cui si è connessi.
    profile.signIn(account: anna)
    check("connesso ad Anna prima di cancellare", profile.account?.id == annaID)
    try profile.deleteAccount(anna)

    let accountsLeft = try context.fetch(FetchDescriptor<UserAccount>()).filter { $0.id == annaID }
    check("account sparito", accountsLeft.isEmpty)
    check("schede sparite",
          try context.fetch(FetchDescriptor<Routine>()).allSatisfy { $0.id != routineID })
    check("giorni spariti",
          try context.fetch(FetchDescriptor<RoutineDay>()).allSatisfy { $0.id != dayID })
    check("esercizi spariti",
          try context.fetch(FetchDescriptor<RoutineItem>()).allSatisfy { $0.id != itemID })
    check("progressi spariti",
          try context.fetch(FetchDescriptor<DayProgress>()).allSatisfy { $0.ownerAccountID != annaID })
    check("storico sparito",
          try context.fetch(FetchDescriptor<WorkoutSession>()).allSatisfy { $0.ownerAccountID != annaID })
    check("legami trainer spariti",
          try context.fetch(FetchDescriptor<TrainerLink>()).allSatisfy { $0.clientAccountID != annaID })
    check("credenziali sparite", !CredentialStore.hasPassword(for: annaID))
    check("sessione chiusa", profile.account == nil)
    check("gli altri profili restano",
          try context.fetch(FetchDescriptor<UserAccount>()).contains { $0.id == bea.id })

    // Pulizia del Portachiavi vero della macchina.
    for account in try context.fetch(FetchDescriptor<UserAccount>()) {
        CredentialStore.removeCredentials(for: account.id)
    }
    CredentialStore.removeCredentials(for: annaID)
}

@main
enum Main {
    static func main() async throws {
        try await run()
        print("\n=== \(passed) passati, \(failed) falliti ===")
        if failed > 0 { exit(1) }
    }
}
