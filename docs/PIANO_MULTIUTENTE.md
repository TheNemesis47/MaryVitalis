# Piano: da app personale ad app pubblica

Trasformare Mary Vitalis da app con 3 persone cablate nel codice ad app che
chiunque può scaricare, configurare e usare — con account propri, schede create
da zero e mappa della propria palestra.

Stato di partenza: 6.773 righe di Swift, iOS 17+, nessuna dipendenza esterna,
persistenza su `UserDefaults`, tutti i dati di dominio sono costanti compilate.

---

## 0. Decisioni prese e loro conseguenze

| Scelta | Conseguenza |
| --- | --- |
| ~~SwiftData + CloudKit privato~~ | **Revocata il 2026-08-02**, vedi §0.3. |
| **SwiftData locale + Firebase** | SwiftData resta il magazzino locale e offline; Firebase Auth e Firestore reggono identità, condivisione e il legame trainer↔cliente. |
| **Sign in with Apple + email/password** | Due livelli distinti di identità, vedi sotto. |
| **Editor mappa a griglia** | L'utente posiziona gli attrezzi su righe/colonne, come la resa attuale. |

### 0.1 I due livelli di identità

CloudKit privato non offre autenticazione con password: l'identità è l'Apple ID.
Salvare hash di password in un database CloudKit pubblico sarebbe insicuro e a
rischio rifiuto in review. Quindi:

**Livello 1 — Identità cloud (Sign in with Apple).**
È il proprietario del contenitore CloudKit privato. Serve a:
- sincronizzare schede, progressi e palestre fra iPhone e iPad della stessa persona;
- reggere il collegamento trainer↔cliente via `CKShare`;
- soddisfare la linea guida Apple 4.8 se in futuro si aggiunge un login sociale.

**Livello 2 — Profili locali con password.**
Più persone che usano lo *stesso* dispositivo. È il caso attuale: un iPhone,
tre persone. La password non è credenziale di rete, è un lucchetto sul profilo:
- hash PBKDF2-SHA256, 210.000 iterazioni, salt casuale da 32 byte;
- hash e salt nel **Keychain**, mai nel database né in CloudKit;
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

Un profilo locale può essere "promosso" collegandolo a un Apple ID: da quel
momento sincronizza.

### 0.3 Perché "solo iCloud" è stata revocata

Il requisito emerso dopo la fase 2 è preciso: *il trainer scrive la scheda a
Pasquale; Pasquale apre l'app sul suo telefono, fa il login e la trova già lì.*
L'associazione avviene con un **codice** che il cliente detta al trainer, e un
trainer segue **molti** clienti.

CloudKit privato non ci arriva: la condivisione fra utenti diversi passa da
`CKShare`, che con SwiftData è il rischio n. 2 di questo stesso piano, e
vincolerebbe entrambe le persone ad avere iCloud attivo. Supabase mette in pausa
i progetti gratuiti dopo una settimana di inattività.

**Firebase, piano Spark**: autenticazione illimitata, 50.000 letture e 20.000
scritture al giorno, 1 GiB. Gratuito, non scade, non va in pausa. In più regala
quello che iCloud non avrebbe mai dato: login con email e password da qualsiasi
dispositivo, e la porta aperta a un client Android o web.

Cosa cambia rispetto a prima:
- **SwiftData resta**, come magazzino locale e offline. Non si butta niente delle
  fasi 1 e 2.
- **CloudKit esce.** `AppDatabase` torna a `cloudKitDatabase: .none`: due
  sincronizzazioni sugli stessi dati litigherebbero.
- I dati escono dal dispositivo → etichette di privacy dell'App Store da
  compilare, e informativa GDPR obbligatoria (era già in lista, §8).
- `CredentialStore` resta solo per i profili storici migrati e per lo sblocco
  locale. L'autenticazione vera passa a Firebase Auth.

### 0.2 Sulla password di default `password`

Come richiesto, Samuel, Maria Pia e Raffaele nascono con password `password`.
Due precisazioni pratiche, non obiezioni:

1. I tre account vengono creati **solo dalla migrazione** del dispositivo che ha
   già i dati vecchi in `UserDefaults`. Un utente nuovo che scarica dall'App
   Store non se li ritrova: vedrebbe tre profili sconosciuti già sbloccabili con
   una password nota, ed è il tipo di cosa che la review nota.
2. I tre account nascono con `mustChangePassword = true`: al primo accesso l'app
   chiede di cambiarla, ma si può rimandare. Nessun blocco.

Se preferisci che i tre esistano comunque su ogni installazione, si toglie la
condizione della migrazione: è una riga.

---

## 1. Il problema strutturale da risolvere per primo

Oggi **l'ID della scheda coincide con l'ID dell'utente e con l'ID dell'account**.
`"samuel"` è contemporaneamente il nome dell'account, il nome della scheda e la
chiave dei progressi. Finché resta così, una persona non può avere due schede e
un trainer non può scriverne una per un cliente.

Punti esatti in cui la conflazione è cablata:

| File | Riga circa | Cosa assume |
| --- | --- | --- |
| `Store/ProfileStore.swift` | 55-65 | `routineIDs(for:)` deriva le schede dall'ID account |
| `Store/ProfileStore.swift` | 16, 42 | fallback su `RoutineData.samuel.id` |
| `Store/WorkoutStore.swift` | 25 | `progress` indicizzato per `routineId` che è l'utente |
| `Store/WorkoutStore.swift` | 44, 65, 71 | `activeUserID` validato contro `RoutineData.routine(id:)` |
| `Store/WorkoutStore.swift` | 147, 161 | storico e calendario filtrati per `routineId == userID` |
| `Store/WorkoutStore.swift` | 169, 199 | il widget e i comandi Live Activity risolvono la scheda dall'enum compilato |
| `Shared/WidgetShared.swift` | 17 | `selectedUserID` con default letterale `"samuel"` |
| `Shared/WidgetShared.swift` | 70-76 | snapshot placeholder con dati di Samuel |

**Regola nuova:** `Account.id` (chi sei) ≠ `Routine.id` (quale scheda) ≠
`Profile.id` (di chi sono i progressi). I progressi si indicizzano su
`(ownerID, routineID, dayID, itemID)`.

---

## 2. Modello dati SwiftData

Nuovo target di file: `MaryVitalis/Data/`. I modelli attuali in `Model/`
diventano DTO di sola lettura per widget e Live Activity.

### 2.1 Entità

```
@Model UserAccount
    id: UUID
    displayName: String
    email: String?                  // profilo locale
    appleUserID: String?            // Sign in with Apple
    role: String                    // member | trainer | admin
    symbolName: String
    accentHex: String
    mustChangePassword: Bool
    restDefaultSeconds: Int         // era mv:rest-default:<id>
    createdAt: Date
    routines: [Routine]             // inverse: Routine.owner
    sessions: [WorkoutSession]
    gyms: [Gym]

@Model TrainerLink               // sostituisce assignedUserIDs: [String]
    id: UUID
    trainerAccountID: UUID
    clientAccountID: UUID
    status: String                  // pending | accepted | revoked
    shareRecordName: String?        // CKShare, fase 3
    createdAt: Date

@Model Routine
    id: UUID
    name, emoji, accentHex, goal, summary: String
    owner: UserAccount?             // di chi è
    authorAccountID: UUID?          // chi l'ha scritta (trainer)
    isTemplate: Bool                // riutilizzabile su più clienti
    sortIndex: Int
    createdAt, updatedAt: Date
    days: [RoutineDay]

@Model RoutineDay                 // numero di giorni libero, non più 1-2-3
    id: UUID
    name: String                    // "Petto e spalle", "Gambe"...
    sortIndex: Int
    preferredWeekday: Int?          // opzionale: lun/mer/ven
    routine: Routine?
    items: [RoutineItem]

@Model RoutineItem
    id: UUID
    exerciseQuery: String           // chiave verso exercises.json
    exerciseName: String            // cache leggibile
    sets: Int
    repsText: String?               // "12", "8-10", "max"
    minutes: Int?                   // blocco cardio
    note: String?
    restOverrideSeconds: Int?
    sortIndex: Int
    day: RoutineDay?

@Model WorkoutSession             // sostituisce HistoryEntry
    id: UUID
    ownerAccountID: UUID
    routineID: UUID
    routineName, accentHex, dayName: String   // denormalizzati per lo storico
    dayIndex: Int
    dateKey: String                 // YYYY-MM-DD
    duration: Double
    sets, setsDone, sips: Int
    effort: Int?

@Model DayProgress                // progressi in corso, chiave composita
    id: UUID
    ownerAccountID: UUID
    routineID: UUID
    dayID: UUID
    itemID: UUID
    completedSets: Int
    updatedAt: Date

@Model Gym
    id: UUID
    ownerAccountID: UUID
    brand, name, city: String
    address: String?
    columns: Int                    // larghezza griglia, default 4
    zones: [GymZone]
    equipment: [GymEquipment]

@Model GymZone
    id, name, subtitle, symbol, colorHex
    startRow, endRow: Int           // le zone diventano fasce di righe
    gym: Gym?

@Model GymEquipment
    id: UUID
    catalogItemID: String?          // se viene dal catalogo di sistema
    name: String
    subtitle: String?
    category: String
    gridRow, gridColumn: Int        // sostituisce CGRect
    muscles: [String]
    howTo: [String]
    tips: [String]
    uncertain: Bool
    gym: Gym?

@Model ExerciseEquipmentLink      // sostituisce GymMap.queryToMachines
    exerciseQuery: String
    equipmentID: UUID
    gymID: UUID
```

### 2.2 Vincoli SwiftData + CloudKit — vanno rispettati o il container non si apre

Sono limiti reali del framework, non preferenze:

- **ogni attributo deve essere opzionale o avere un valore di default**;
- **`@Attribute(.unique)` è vietato** → l'unicità si fa a mano in fase di scrittura;
- **ogni relazione deve avere l'inversa dichiarata**, e deve essere opzionale;
- **niente `@Model` senza inizializzatore di default per tutti i campi**;
- gli enum vanno salvati come `String`/`Int` grezzi, non come tipi Swift.

Per questo sopra i ruoli e le categorie sono `String` e non `UserRole` /
`GymMachine.Category`. Gli enum restano, come computed property di accesso:

```swift
extension UserAccount {
    var userRole: UserRole {
        get { UserRole(rawValue: role) ?? .member }
        set { role = newValue.rawValue }
    }
}
```

### 2.3 Il parsing regex delle serie va in pensione

`Plan(details:)` in `Model/Routine.swift:15-44` estrae le serie da stringhe tipo
`"4 serie x 12 ripetizioni"` con due espressioni regolari. Andava bene per dati
scritti da te; con dati scritti dagli utenti è fragile.

`RoutineItem` porta `sets`, `repsText`, `minutes` come campi veri. `details`
diventa una stringa **generata**, mantenuta per la Live Activity e per il
formato dello storico:

```swift
var details: String {
    if let minutes { return "\(minutes) min" + (note.map { " - \($0)" } ?? "") }
    return "\(sets) serie x \(repsText ?? "?") ripetizioni"
}
```

Il vecchio `Plan` resta solo nel percorso di migrazione, per leggere le 3 schede
esistenti.

---

## 3. Autenticazione

### 3.1 Sign in with Apple

- Capability **Sign in with Apple** su target app (non sull'estensione widget).
- `ASAuthorizationAppleIDButton` nella `LoginView` riscritta.
- `userIdentifier` salvato nel Keychain; `email` e `fullName` arrivano **solo
  alla prima autorizzazione** — se non li si salva subito sono persi per sempre.
- All'avvio: `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)`.
  Se `.revoked` o `.notFound` → logout e ritorno alla `LoginView`.
- Gestire il caso "Nascondi la mia email" (`@privaterelay.appleid.com`).

### 3.2 Profili locali con password

Nuovo `Store/CredentialStore.swift`:

```swift
enum CredentialStore {
    static func setPassword(_ password: String, for accountID: UUID) throws
    static func verify(_ password: String, for accountID: UUID) -> Bool
    static func removeCredentials(for accountID: UUID)
}
```

- PBKDF2-SHA256, 210.000 iterazioni (raccomandazione OWASP 2023), salt 32 byte
  da `SecRandomCopyBytes`;
- confronto a tempo costante;
- `SecureSessionStore` esistente viene esteso: oggi salva un `String` account id
  (`Store/SecureSessionStore.swift:25`), passa a salvare un `UUID` + timestamp
  di sessione.

### 3.3 Cancellazione account — obbligatoria

Linea guida App Store **5.1.1(v)**: un'app che permette di creare un account
deve permettere di cancellarlo dall'app, non solo di disconnettersi. Serve:
- voce "Elimina account" in `SettingsView`;
- cancellazione a cascata dei dati SwiftData locali;
- cancellazione della zona CloudKit privata dell'utente;
- revoca del token Sign in with Apple (`REST` verso Apple oppure istruzione
  esplicita all'utente su come revocare da Impostazioni iOS).

---

## 4. Editor delle schede

Nuove viste in `MaryVitalis/Views/Editor/`:

| Vista | Cosa fa |
| --- | --- |
| `RoutineListView` | Le schede dell'utente (o del cliente selezionato dal trainer). Crea, duplica, elimina, riordina. |
| `RoutineEditorView` | Nome, emoji, colore, obiettivo, descrizione. Lista dei giorni con aggiunta/rimozione/riordino: **numero libero**, da 1 a N. |
| `DayEditorView` | Nome del giorno, giorno della settimana opzionale, lista esercizi riordinabile. |
| `ExercisePickerView` | Riuso di `ExercisesView` in modalità selezione: cerca fra i 1324 esercizi, filtra per distretto/muscolo/attrezzo, GIF di anteprima. |
| `RoutineItemEditor` | Serie, ripetizioni, minuti (cardio), recupero specifico, nota. Segmented control serie/cardio. |

Comportamenti:
- **Duplica giorno** e **duplica scheda** — la richiesta più frequente quando si
  costruisce un mesociclo.
- **Template**: un trainer marca una scheda come template e la applica a più
  clienti. La copia è per valore: modificare il template non tocca le schede già
  assegnate.
- Salvataggio continuo, niente pulsante "Salva": è il comportamento atteso su iOS.

Le 3 schede attuali (`Model/RoutineData.swift`) diventano **template di sistema**
in un JSON del bundle: `Resources/starter-routines.json`. Un utente nuovo può
partire da lì invece che dal foglio bianco.

---

## 5. Editor della mappa palestra

### 5.1 Dal rilievo alla griglia

Oggi `GymMachine.rect` è un `CGRect` col rilievo originale, e
`GymMapView.swift:412-418` ricava righe e colonne ordinando per `center.y` e
`center.x`. Nel nuovo modello `gridRow`/`gridColumn` sono **dati primi**: la
griglia non va più dedotta.

Conversione una tantum dei 53 attrezzi: script che applica l'algoritmo attuale di
`spatialRows` e sputa un JSON con riga e colonna già calcolate →
`Resources/equipment-catalog.json`. Diventa il **catalogo di sistema** da cui
tutti pescano, con testi `howTo` e `tips` già scritti.

### 5.2 Le viste

| Vista | Cosa fa |
| --- | --- |
| `GymListView` | Le palestre dell'utente. Una è "attiva". |
| `GymEditorView` | Griglia a N colonne (2-6, default 4). Ogni cella è vuota o contiene un attrezzo. Drag & drop per spostare, tap lungo per rimuovere. Aggiunta/rimozione righe in fondo. |
| `EquipmentPickerSheet` | Catalogo di sistema per categoria, ricerca testuale, più "Attrezzo personalizzato". |
| `EquipmentEditorView` | Nome, categoria, muscoli, istruzioni, avvertenze, flag "da identificare". |
| `ZoneEditorView` | Zone come fasce di righe: nome, colore, simbolo, riga di inizio e fine. |

`GymMapView.swift` (652 righe, il nodo più connesso del progetto con 33 collegamenti)
si semplifica: legge `gridRow`/`gridColumn` invece di calcolarli. Va toccato con
attenzione perché è il ponte fra mappa, dati e tema.

### 5.3 Collegamento esercizio→attrezzo

`GymMap.queryToMachines` (`Model/GymMapData.swift:609`) è un dizionario cablato
con l'euristica di fallback a riga 640-655. Diventa:
1. `ExerciseEquipmentLink` esplicito, creato dall'utente dal dettaglio esercizio
   ("Dove si fa" → "Collega a un attrezzo");
2. suggerimento automatico con l'euristica attuale sul nome, mostrato come
   proposta da confermare;
3. l'utente può correggere sempre.

---

## 6. Widget e Live Activity

Problema: `WorkoutStore.consumeWidgetCommands` risolve la scheda con
`RoutineData.routine(id:)` (`Store/WorkoutStore.swift:199`), cioè legge un enum
compilato. L'estensione widget **non può accedere a SwiftData+CloudKit** in modo
affidabile e non deve.

Soluzione: l'app pubblica nell'App Group uno snapshot completo della sessione
attiva. Il meccanismo esiste già (`MaryVitalisShared.saveSnapshot`), va esteso.

Modifiche:
- `WorkoutWidgetSnapshot`: aggiungere `routineID: UUID`, `dayID: UUID`,
  e `items: [ItemSnapshot]` (id, nome, serie totali) della giornata in corso;
- rimuovere il placeholder cablato su Samuel (`Shared/WidgetShared.swift:70-76`)
  → placeholder neutro, senza nomi;
- `selectedUserID` diventa `activeAccountID: UUID?`, senza default `"samuel"`
  (`Shared/WidgetShared.swift:17`);
- `WorkoutWidgetCommand.routineID` da `String` a `UUID`;
- `consumeWidgetCommands` valida contro lo snapshot, non contro `RoutineData`.

Rischio: il formato dei dati condivisi cambia. Un utente che aggiorna con una
Live Activity in corso può vederla bloccata. Mitigazione: `schemaVersion` nello
snapshot, e alla prima apertura post-aggiornamento le attività orfane vengono
terminate.

---

## 7. Migrazione dei dati esistenti

Una tantum, alla prima apertura della nuova versione. `Data/LegacyMigrator.swift`.

| Sorgente `UserDefaults` | Destinazione |
| --- | --- |
| `mv:progress` → `[routineId: [day: [ex: count]]]` | `DayProgress`, mappando l'indice esercizio all'`itemID` nuovo |
| `mv:history` → `[HistoryEntry]` | `WorkoutSession` |
| `mv:rest-default:<id>` e `mv:rest-default` | `UserAccount.restDefaultSeconds` |
| `RoutineData.samuel/raffaele/mariapia` | 3 `Routine` di proprietà dei 3 account |
| `AccountData.all` | 3 `UserAccount` + 2 `TrainerLink` (Maria Pia → Samuel, Raffaele) |
| Keychain `it.maryvitalis.app.session` | sessione attiva |

L'account `admin` non viene migrato: era uno strumento di sviluppo, non ha senso
in un'app pubblica. Il ruolo `admin` resta nell'enum ma nessuno lo assume.

Regole: la migrazione è **idempotente** (flag `mv:migrated-v2` a fine corsa),
non cancella le chiavi vecchie per almeno una versione, e se fallisce non lascia
il database a metà (`ModelContext` singolo, un solo `save()` finale).

---

## 8. Requisiti App Store

Cose che bloccano la pubblicazione se mancano:

- [ ] **Privacy policy** con URL pubblico raggiungibile — obbligatoria, non
      opzionale, per ogni app con account.
- [ ] **Privacy manifest** `PrivacyInfo.xcprivacy` con le `NSPrivacyAccessedAPITypes`
      per `UserDefaults` (motivo `CA92.1`) e per il file timestamp API.
- [ ] **Cancellazione account in-app** (5.1.1(v)) — vedi §3.3.
- [ ] **Export compliance**: l'app usa solo crittografia standard di sistema
      (Keychain, HTTPS) → esente, ma va dichiarato in `Info.plist` con
      `ITSAppUsesNonExemptEncryption = NO`.
- [ ] **Disclaimer sanitario**: l'app propone esercizi fisici e la scheda di
      Samuel nasce da un percorso post-operatorio. Serve un avviso esplicito
      "non è un consiglio medico, consulta un professionista" all'onboarding.
- [ ] **Attribuzione media**: le GIF vengono da `raw.githubusercontent.com`
      (© Gym Visual). Verificare la licenza per uso commerciale prima della
      pubblicazione — è il rischio legale più concreto del progetto.
- [ ] **Dipendenza di rete**: la griglia esercizi non funziona offline. Serve
      almeno uno stato di errore decente e una cache su disco
      (`RemoteMediaCache` oggi è solo in memoria).
- [ ] **Localizzazione**: l'app è tutta in italiano hardcoded. Per "funziona per
      tutti" serve almeno l'inglese — `exercises.json` ha già entrambe le lingue.

---

## 9. Fasi

Ogni fase lascia l'app funzionante e compilabile.

**Fase 1 — Fondamenta dati** ✅ *fatta*
1. ✅ Modelli SwiftData e `ModelContainer` (`cloudKitDatabase: .automatic`:
   sincronizza appena il target ha la capability iCloud, vedi §9-bis).
2. ✅ `LegacyMigrator`, verificato su dati legacy veri: progressi rimappati per
   identificativo, storico, preferenze di recupero, backup su disco, idempotenza.
3. ✅ `ProfileStore` e `WorkoutStore` riscritti su SwiftData, conflazione ID rotta.
4. ✅ Snapshot widget esteso, `WorkoutWidgetCommand` su UUID, placeholder neutro.
5. ✅ `CredentialStore` (PBKDF2-SHA256, 210k iterazioni) — anticipato dalla fase 2
   perché la migrazione è l'unico punto in cui nascono i tre profili storici.

*Non verificato end-to-end:* il giro password nella UI (scrittura e rilettura dal
Portachiavi). La derivazione PBKDF2 è verificata contro i vettori RFC.

**Fase 9-bis — Accendere la sincronizzazione iCloud**
In Xcode, target MaryVitalis → Signing & Capabilities: scegli il team, aggiungi
**iCloud** con CloudKit e un contenitore `iCloud.it.maryvitalis.app`. Non serve
toccare il codice: `AppDatabase` è già configurato per usarlo quando c'è.

**Fase 2 — Account veri** ✅ *fatta*
6. ✅ `LoginView` con Sign in with Apple e registrazione.
7. ✅ Onboarding: crea account → scegli una scheda di partenza o parti da zero.
8. ✅ Cancellazione account a cascata (§3.3).
9. ✅ Cambio password, richiesta di cambio per i profili storici, e creazione dei
   tre profili storici ristretta ai dispositivi con dati legacy (§0.2).
10. ✅ Avviso quando `AppDatabase.isEphemeral` è `true`.

*Verifica:* `Tests/AccountHarness/run.sh` — 36 controlli sul codice di produzione
vero (registrazione, validazione, accesso, cambio password, Sign in with Apple,
cancellazione a cascata). Più le due installazioni nel simulatore: pulita → zero
profili e schermata di benvenuto; con dati vecchi → i tre profili e lo storico.

*Non verificato:* il flusso Sign in with Apple vero richiede un Apple ID nel
simulatore e la capability firmata; è verificata la logica che gli sta sotto.
*Verifica: si installa su un dispositivo pulito e si arriva ad allenarsi.*

**Fase 3 — Editor schede** ✅ *fatta*
9. ✅ `RoutinesView` con creazione, duplicazione ed eliminazione;
   `RoutineEditorView`, `DayEditorView`, `ExercisePickerView`,
   `RoutineItemEditorView`. Logica in `Store/RoutineEditing.swift`.
10. ✅ Giorni in numero libero, riordinabili, con giorno della settimana opzionale.
11. ✅ Duplicazione per valore: modificare l'originale non tocca la copia.
12. ✅ Il trainer scrive sul profilo consultato: la scheda è del cliente
    (`owner`), l'autore resta il trainer (`authorAccountID`), e parte subito
    verso il cloud.

*Verifica:* 25 controlli nel banco di prova (creazione, giorni, esercizi,
riordino, cardio, duplicazione indipendente, scrittura per conto del cliente).
Ha trovato un difetto reale: cancellando un giorno o un esercizio, gli indici
restavano bucati perché l'oggetto cancellato resta nella relazione del genitore
finché non si salva. Corretto staccando la relazione prima della cancellazione.

**Fase 4 — Editor mappa**
12. Conversione dei 53 attrezzi in catalogo JSON.
13. `GymListView`, `GymEditorView` con griglia drag & drop.
14. Collegamento esercizio→attrezzo modificabile.

**Fase 5 — Trainer e cloud**
15. ✅ Codice invito, richiesta di collegamento, consenso del cliente, revoca da
    entrambe le parti, molti clienti per trainer. Verificato dal banco di prova.
16. ✅ UI: "Il tuo codice", richieste in sospeso, elenco clienti, aggiunta con codice.
17. ✅ **Firebase** (progetto `maryvitalis-a68f4`)
    - pacchetto SPM `firebase-ios-sdk` 11.15.0 (FirebaseAuth, FirebaseFirestore)
    - `AuthService`: email/password e Apple con `nonce`
    - `CloudSync`: `users`, `inviteCodes`, `trainerLinks`, `routines`, con
      ascolto in tempo reale e cache su disco per l'uso offline
    - una scheda = **un documento**, giorni ed esercizi annidati
    - cancellazione account estesa al cloud, prima di eliminare l'utente di Auth
    - `AppDatabase` è tornato a `cloudKitDatabase: .none`

    *Verifica:* `Tests/CloudRules/verifica.py` — 28 controlli contro il progetto
    Firebase vero, con tre account di prova creati e poi rimossi. Ha trovato una
    falla reale nelle regole (vedi sotto).

18. Vista trainer: schede del cliente selezionato e ultimi allenamenti.
19. Sincronizzazione di storico e progressi (regole già pronte, codice no).

**Falla trovata e chiusa il 2026-08-02.** La regola su `inviteCodes` concedeva
`create, update, delete` guardando solo `request.resource.data.userId`, cioè il
documento *in arrivo*. Chiunque poteva quindi riscrivere il codice invito di un
altro puntandolo a sé: un trainer che digitava il codice del proprio cliente si
sarebbe collegato all'attaccante. Corretta separando i tre permessi — `update` e
`delete` richiedono di possedere il documento **esistente**. Nella stessa regola
`delete` usava `request.resource`, che in cancellazione non esiste: i codici
liberati sarebbero rimasti a puntare al vecchio proprietario per sempre.

**Fase 6 — Pubblicazione**
18. Privacy policy, manifest, disclaimer, export compliance.
19. Localizzazione inglese.
20. Schermate App Store, descrizione, TestFlight esterno.

---

## 10. Rischi, in ordine di gravità

1. **Licenza delle GIF (Gym Visual)**. Uso personale e uso commerciale sono cose
   diverse. Da verificare **prima** di scrivere codice: se la licenza non regge,
   cambia il contenuto dell'app, non solo un dettaglio.
2. **CKShare con SwiftData**. SwiftData non espone bene il database `.shared`:
   la fase 5 potrebbe richiedere CloudKit "a mano" accanto a SwiftData, o un
   ripiego (la scheda si esporta come file/QR e il cliente la importa). Da
   prototipare presto, prima di prometterlo nella UI.
3. **Migrazione**. Se sbaglia, perdi lo storico reale di tre persone. Backup
   JSON delle chiavi `UserDefaults` su file prima di iniziare, e nessuna
   cancellazione delle chiavi vecchie per almeno una versione.
4. **`GymMapView`**. 652 righe, 33 collegamenti nel grafo, ponte fra tre aree.
   È dove è più facile rompere qualcosa senza accorgersene.
5. **Numero di giorni libero**. `RecapView`, `CalendarView` e `HomeView`
   assumono in più punti una scheda con pochi giorni fissi. Da verificare con
   una scheda a 6 giorni e una a 1 giorno.
6. **Password di default nota**. Vedi §0.2.

---

## 11. Cosa NON è in questo piano

Per scelta, per non gonfiare la prima versione pubblica:

- Backend proprio e login multi-dispositivo con password (serve un server).
- Client Android o web.
- Abbonamenti e pagamenti.
- Social, classifiche, feed.
- Integrazione HealthKit (candidata naturale per la versione successiva).
- Palestre pubbliche condivise fra utenti diversi.
