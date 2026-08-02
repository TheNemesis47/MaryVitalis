# Mary Vitalis — app iOS

App SwiftUI per schede, sessioni e progressi in palestra, con widget,
Live Activity e una mappa spaziale predisposta per più sedi.

Target: iOS 17+, iPhone e iPad. Nessuna dipendenza esterna.

## Aprire il progetto

```
open MaryVitalis.xcodeproj
```

Il target usa un *file system synchronized group*: tutto quello che sta dentro
`MaryVitalis/` entra nel build automaticamente, senza toccare il `.pbxproj`.
Prima di lanciare, in **Signing & Capabilities** scegli il tuo team per l'app e
per `MaryVitalisWidgets`. I bundle id sono `it.maryvitalis.app` e
`it.maryvitalis.app.widgets`; entrambi usano l'App Group
`group.it.maryvitalis.shared`.

## Cosa c'è dentro

| Schermata | Contenuto |
| --- | --- |
| **Accesso** | sessione locale una tantum con ruoli utente, trainer e admin |
| **Home** | statistiche, schede in evidenza, distretti muscolari |
| **Esercizi** | i 1324 esercizi del dataset, filtrabili per distretto/muscolo/attrezzo, con GIF animata e istruzioni passo passo |
| **Schede** | le 3 schede (Samuel, Raffaele, Maria Pia) e la **modalità allenamento** |
| **Mappa** | sedi selezionabili, zone della sala e 53 attrezzi interattivi |
| **Recap** | settimana, calendario, andamento dello sforzo, storico |
| **Impostazioni** | account, profilo consultato e recupero personalizzato |

### Modalità allenamento

Identica alla versione web:

- si sceglie il giorno sul calendario, poi parte cronometro e checklist;
- le serie si segnano **in ordine**: toccando la n-esima si completano anche le
  precedenti, ritoccandone una già fatta si torna indietro; `↺` azzera l'esercizio;
- i blocchi cardio hanno "segna fatto" più un timer sui minuti previsti;
- timer di recupero automatico a ogni serie (45/60/90/120s, −15s/+15s, pausa,
  salta) con suono sintetizzato e vibrazione;
- **Live Activity** su Lock Screen e Dynamic Island con esercizio corrente,
  serie numerate interattive e controlli del recupero;
- **sorsi d'acqua**: promemoria ogni 10 minuti con aggiunta rapida di 3 sorsi,
  più `+1` manuale;
- a fine allenamento si segna lo **sforzo percepito** (1–10) e la sessione va
  nello storico.

Progressi e storico restano sul dispositivo. Lo stato necessario a widget e
Live Activity è condiviso tra app ed estensione tramite App Group.

### Account, ruoli e recap

La build TestFlight usa per ora un accesso locale: l'identificativo della
sessione viene conservato nel Portachiavi di iOS, mentre non esistono password
locali. Samuel e Raffaele sono utenti normali; Maria Pia è trainer di Samuel e
Raffaele e può consultare i loro profili; il ruolo admin può consultare tutti.
Schede, preferenza di recupero, widget e recap seguono il profilo consultato.
Un login reale multi-dispositivo richiederà un backend e token server-side.

### Widget e utente attivo

Il widget “Ultimo allenamento” mostra da quanti giorni l'utente selezionato non
si allena. È disponibile nella Home Screen e nei formati compatibili con la
Lock Screen. L'utente attivo (Samuel, Raffaele o Maria Pia) si sceglie dalle
impostazioni aperte con l'icona ingranaggio nella Home.

Durante una scheda l'app avvia automaticamente una Live Activity in stile
tracking: mostra esercizio e serie correnti, permette di segnare una serie e di
scegliere, allungare, mettere in pausa o saltare il recupero. Per ragioni di
sicurezza iOS richiede l'autenticazione quando il telefono è bloccato; dopo
Face ID o codice l'azione viene eseguita senza dover aprire manualmente l'app.

### Mappa multi-palestra

La prima sede del catalogo è **FitActive Napoli Birreria**. Il modello
`GymCatalog` separa la sede dai macchinari, quindi nuove palestre possono avere
aree e attrezzi propri senza duplicare la schermata.

Il rilievo originale fornisce soltanto area e ordine spaziale. La UI non mostra
una planimetria né zone colorate: tutti gli attrezzi sono disposti in una griglia
spaziale a quattro colonne, scorrevole verticalmente. Riga e colonna derivano
dalle coordinate originali; quando nel rilievo manca una postazione, la relativa
cella resta vuota invece di ricompattare gli attrezzi verso sinistra. Ogni scheda
mostra nome e gruppo principale; il tap apre tutti i dettagli e l'esecuzione.
Ogni attrezzo apre una scheda che raggruppa nome, categoria, gruppi muscolari,
esercizi compatibili, istruzioni e avvertenze.

**Durante l'allenamento** la mappa evidenzia “ORA” in azzurro, “POI” in arancio
e “FATTO” in grigio. Dal link “Dove si fa” scorre direttamente alla riga
dell'attrezzo; il pannello conserva anche un pulsante esplicito per tornare alla
scheda.

Le immagini reali usate durante il rilievo non sono mostrate e sono escluse dal
bundle dell'app. I macchinari ancora dubbi espongono un avviso testuale e possono
essere corretti direttamente nei dati della sede.

Gli attrezzi che il PDF stesso segnalava come "da identificare" sono marcati con
`uncertain: true` e mostrano un avviso giallo nella scheda: la panca declinata,
la macchina Matrix in basso a sinistra, l'area a corpo libero inclinata a 45° e
le tre macchine cardio non ricordate.

## Struttura

```
MaryVitalis/
  MaryVitalisApp.swift
  Model/
    Exercise.swift          voce del database
    AppAccount.swift        account locali, ruoli e assegnazioni trainer
    Routine.swift           schede, giorni, parsing di "4 serie x 12"
    RoutineData.swift       le 3 schede
    GymLocation.swift       catalogo sedi, zone e selezione palestra
    GymMachine.swift        identità, muscoli e posizione di un attrezzo
    GymMapData.swift        rilievo FitActive Napoli Birreria + query esercizi
    Formatters.swift        date italiane, cronometro, medie
  Store/
    ExerciseLibrary.swift   carica exercises.json fuori dal main thread
    ProfileStore.swift      utente selezionato condiviso con i widget
    SecureSessionStore.swift sessione locale nel Portachiavi iOS
    WorkoutStore.swift      progressi e storico persistiti
    SessionController.swift cronometro, recupero, acqua e Live Activity
    WorkoutActivityManager.swift  ciclo di vita ActivityKit
    Feedback.swift          suono sintetizzato + haptics
  Views/
    RootView.swift          TabView (Home/Esercizi/Schede/Mappa/Recap)
    Theme.swift             design system portato da style.css
    HomeView, ExercisesView, ExerciseDetailView, AnimatedImageView
    RoutinesView, RoutineDetailView, SessionComponents, CalendarView
    GymMapView, MachineDetailView, RecapView, SettingsView
  Resources/
    exercises.json          1324 esercizi (it/en), 2.8 MB
MaryVitalisWidgets/
  WorkoutStreakWidget.swift widget ultimo allenamento
  WorkoutLiveActivity.swift Lock Screen e Dynamic Island
Shared/
  WidgetShared.swift        stato condiviso app/estensione
  WorkoutIntents.swift      azioni Live Activity compilate in entrambi i target
```

## Dati

`Resources/exercises.json` è la versione ridotta di `exercises.json` del sito:
mantiene solo italiano e inglese per istruzioni e passi. Immagini e GIF non sono
in bundle: vengono caricate a runtime dallo stesso repo usato dal sito
(`raw.githubusercontent.com/hasaneyldrm/exercises-dataset`), quindi la griglia
esercizi ha bisogno di rete. Media © Gym Visual.

Per aggiungere una scheda basta un nuovo `Routine` in `RoutineData.all`. Se
introduce esercizi nuovi, aggiungi la riga corrispondente in
`GymMap.queryToMachines` perché la sede sappia quale pin accendere
(altrimenti interviene l'euristica su attrezzo/nome).
