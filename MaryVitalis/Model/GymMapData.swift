import SwiftUI

/// Rilievo dati della sede FitActive La Birreria. Le coordinate servono solo
/// ad associare gli attrezzi alle aree e a mantenere un ordine coerente.
enum GymMap {
    static let machines: [GymMachine] = fixedMachines + repeatedMachines

    static func machine(id: String) -> GymMachine? { machines.first { $0.id == id } }

    static var byCategory: [(GymMachine.Category, [GymMachine])] {
        GymMachine.Category.allCases.compactMap { cat in
            let list = machines.filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    // MARK: - Attrezzi singoli

    private static let fixedMachines: [GymMachine] = [
        GymMachine(
            id: "pedana-vibrante",
            name: "Pedana vibrante",
            subtitle: "Active Vibration — con poster istruzioni a muro",
            category: .altro,
            rect: CGRect(x: 325.5, y: 0, width: 83.1, height: 34.6),
            muscles: ["Total body", "Propriocezione", "Flessibilità"],
            howTo: [
                "Sali sulla pedana senza scarpe: è la regola esposta in sala.",
                "Tieni sempre le gambe morbide, mai bloccate: le fibre devono assorbire la vibrazione.",
                "Riscaldamento ed elasticità: 30\" per posizione, frequenza bassa.",
                "Lavoro: 30\" di esercizio e 30\" di recupero, alternando distretti diversi.",
                "Chiudi con lo stretching seguendo le posizioni 14 e successive del poster."
            ],
            tips: [
                "Sconsigliata in gravidanza, con protesi d'anca o ginocchio, ernia acuta, epilessia, pacemaker, trombosi, malattie cardiovascolari, diabete, ferite fresche o interventi recenti.",
                "Se non riesci a terminare l'esercizio, fermati: 10 secondi ben fatti valgono più di un minuto rigido."
            ]
        ),
        GymMachine(
            id: "area-corpo-libero",
            name: "Attrezzo a corpo libero inclinato",
            subtitle: "Piano a 45°, si scende con la schiena",
            category: .liberi,
            rect: CGRect(x: 221.6, y: 34.6, width: 55.4, height: 69.3),
            muscles: ["Core", "Lombari", "Glutei"],
            howTo: [
                "Sistemati sul piano inclinato a circa 45° con i piedi bloccati sotto i rulli.",
                "Scendi con la schiena controllando il movimento, senza andare in iperestensione.",
                "Risali fino all'allineamento busto-bacino-gambe e fermati lì.",
                "Espira nella risalita, inspira nella discesa."
            ],
            tips: [
                "Sulla mappa originale è indicato solo come \"attrezzo a corpo libero dove si sta tipo inclinati a 45°\": in sala verifica la targhetta."
            ],
            uncertain: true
        ),
        GymMachine(
            id: "leg-press",
            name: "Leg press",
            subtitle: "45° a dischi + versione seduta a pacco",
            category: .forza,
            rect: CGRect(x: 97, y: 41.5, width: 55.4, height: 34.7),
            muscles: ["Quadricipiti", "Glutei", "Femorali"],
            howTo: [
                "Da seduto, usa il perno per impostare una posizione di partenza comoda.",
                "Appoggia i piedi sulla pedana alla larghezza delle spalle e impugna le maniglie ai lati del sedile.",
                "Spingi con i talloni fino quasi a estendere le ginocchia, senza bloccarle.",
                "Torna giù lentamente fino a circa 90° di piega del ginocchio."
            ],
            tips: [
                "Non staccare mai la zona lombare dallo schienale.",
                "Sulla versione a 45° a dischi ricordati di riagganciare le sicure a fine serie."
            ]
        ),
        GymMachine(
            id: "hack-squat",
            name: "Hack squat",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 97, y: 83.1, width: 55.4, height: 34.6),
            muscles: ["Quadricipiti", "Glutei"],
            howTo: [
                "Appoggia spalle e schiena ai cuscinetti, piedi sulla pedana leggermente avanti.",
                "Sgancia le sicure ruotando le maniglie laterali.",
                "Scendi controllato fino a circa 90° tenendo la schiena aderente.",
                "Risali spingendo con tutta la pianta del piede senza bloccare le ginocchia."
            ],
            tips: ["Carico assiale sulla colonna: da evitare in caso di problemi lombari."]
        ),
        GymMachine(
            id: "rear-delt-pec-fly",
            name: "Rear delt / Pec fly",
            subtitle: "FitActive — doppia funzione",
            category: .forza,
            rect: CGRect(x: 401.7, y: 96.9, width: 55.4, height: 34.7),
            muscles: ["Pettorali", "Deltoidi posteriori"],
            howTo: [
                "Regola l'altezza della seduta in modo da allineare le maniglie con le spalle.",
                "Regola la posizione delle maniglie scegliendo il movimento: Rear delt (deltoidi posteriori) o Pec fly (pettorali).",
                "Pec fly: petto in appoggio, chiudi le braccia davanti con i gomiti morbidi.",
                "Rear delt: petto contro il cuscino, apri le braccia indietro stringendo le scapole."
            ],
            tips: ["La macchina ha due configurazioni: controlla la posizione delle leve prima di iniziare."]
        ),
        GymMachine(
            id: "prone-leg-curl",
            name: "Prone leg curl",
            subtitle: "FitActive — leg curl prono",
            category: .forza,
            rect: CGRect(x: 41.5, y: 124.6, width: 55.5, height: 34.7),
            muscles: ["Femorali", "Polpacci"],
            howTo: [
                "Sdraiati a pancia in giù e posiziona il cuscinetto delle gambe comodamente dietro le caviglie.",
                "Allinea le ginocchia con l'asse di rotazione del perno.",
                "Posiziona il cuscinetto degli avambracci a un'altezza comoda e afferra le maniglie.",
                "Fletti le gambe portando i talloni verso i glutei, poi torna giù senza far cadere il peso."
            ],
            tips: ["Tieni il bacino aderente al piano: se si stacca, il carico è troppo alto."]
        ),
        GymMachine(
            id: "glute",
            name: "Glute",
            subtitle: "Technogym",
            category: .forza,
            rect: CGRect(x: 97, y: 124.6, width: 55.4, height: 34.7),
            muscles: ["Glutei", "Femorali"],
            howTo: [
                "Regola il cuscinetto sul petto a un'altezza confortevole.",
                "Appoggia l'avambraccio e il petto, un piede sulla pedana e l'altro sulla leva.",
                "Spingi indietro la gamba estendendo l'anca, senza inarcare la schiena.",
                "Torna in posizione controllando il ritorno, poi cambia gamba."
            ],
            tips: ["Il movimento parte dal gluteo, non dalla zona lombare."]
        ),
        GymMachine(
            id: "seated-row",
            name: "Seated row",
            subtitle: "Technogym",
            category: .forza,
            rect: CGRect(x: 256.2, y: 124.6, width: 55.4, height: 34.7),
            muscles: ["Dorsali", "Romboidi", "Bicipiti"],
            howTo: [
                "Regola l'altezza della seduta per un miglior comfort.",
                "Posiziona il cuscino sul petto e afferra le impugnature.",
                "Tira verso di te stringendo le scapole, gomiti vicini al corpo.",
                "Accompagna il ritorno fino a sentire l'allungamento dorsale."
            ],
            tips: ["Non staccare il petto dal cuscino per aiutarti con la schiena."]
        ),
        GymMachine(
            id: "cardio-non-identificato",
            name: "Altre 3 macchine cardio",
            subtitle: "Non identificate sulla mappa",
            category: .cardio,
            rect: CGRect(x: 422.4, y: 145.4, width: 41.6, height: 110.8),
            muscles: ["Cardio"],
            howTo: ["Zona cardio: la mappa originale riporta \"ce ne sono altre 3 ma non ricordo\"."],
            tips: ["Da verificare in sala e aggiornare in GymMapData.swift."],
            uncertain: true
        ),
        GymMachine(
            id: "matrix-da-identificare",
            name: "Macchina Matrix da identificare",
            subtitle: "Pedana ampia + cuscinetto e rullo",
            category: .forza,
            rect: CGRect(x: 41.5, y: 166.2, width: 55.5, height: 34.6),
            muscles: ["Glutei", "Femorali"],
            howTo: [
                "La configurazione rilevata sembra adatta alla spinta d'anca (glute drive / hip thrust): verifica la targhetta prima dell'uso.",
                "Prima di usarla leggi la targhetta sull'attrezzo."
            ],
            tips: ["Il rilievo iniziale non riportava un nome certo: verifica la targhetta in sede."],
            uncertain: true
        ),
        GymMachine(
            id: "leg-curl-extension",
            name: "Leg curl / Leg extension",
            subtitle: "Matrix — doppia funzione",
            category: .forza,
            rect: CGRect(x: 97, y: 166.2, width: 55.4, height: 34.6),
            muscles: ["Quadricipiti", "Femorali"],
            howTo: [
                "Leg curl: regola lo schienale per allineare il ginocchio col perno arancione, cuscinetto sopra il tallone.",
                "Leg extension: regola lo schienale, cuscinetto sulla gamba sotto la caviglia.",
                "Estendi o fletti in modo controllato, senza slanci.",
                "Fermati un istante nel punto di massima contrazione."
            ],
            tips: ["Blocca il carico con il perno prima di partire."]
        ),
        GymMachine(
            id: "diverging-seated-row",
            name: "Diverging seated row",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 318.6, y: 166.2, width: 55.4, height: 34.6),
            muscles: ["Dorsali", "Trapezio", "Bicipiti"],
            howTo: [
                "Sistema l'altezza della seduta in modo da allineare le maniglie superiori con la parte alta delle spalle.",
                "Posiziona il poggia-petto in modo da raggiungere entrambe le maniglie.",
                "Afferra le prese verticali o parallele.",
                "Tira le maniglie verso di te e torna in posizione."
            ],
            tips: ["Le maniglie divergenti permettono di variare la presa: prova entrambe."]
        ),
        GymMachine(
            id: "hip-adductor-abductor",
            name: "Hip Adductor / Abductor",
            subtitle: "Technogym — doppia funzione",
            category: .forza,
            rect: CGRect(x: 97, y: 207.8, width: 76.1, height: 34.6),
            muscles: ["Adduttori", "Abduttori", "Glutei"],
            howTo: [
                "Ruota i cuscini per le ginocchia e scegli l'esercizio desiderato (adduzione o abduzione).",
                "Regola i cuscini per le ginocchia nella posizione desiderata.",
                "Siediti con la schiena in appoggio e chiudi o apri le gambe con movimento lento.",
                "Controlla sempre il ritorno, senza far sbattere i pesi."
            ],
            tips: ["Perfetto quando serve lavorare le gambe senza stress su ginocchio e colonna."]
        ),
        GymMachine(
            id: "converging-chest-press",
            name: "Converging chest press",
            subtitle: "FitActive",
            category: .forza,
            rect: CGRect(x: 318.6, y: 207.8, width: 55.4, height: 34.6),
            muscles: ["Pettorali", "Deltoidi anteriori", "Tricipiti"],
            howTo: [
                "Regola l'altezza di seduta in modo che le manopole siano a metà del tronco.",
                "Schiena aderente allo schienale, piedi ben piantati.",
                "Spingi in avanti facendo convergere le maniglie, senza bloccare i gomiti.",
                "Torna indietro controllando fino a sentire l'apertura del petto."
            ],
            tips: ["Le maniglie convergono: il movimento finisce naturalmente verso il centro."]
        ),
        GymMachine(
            id: "dip-chin-assist",
            name: "Dip assist / Chin assist",
            subtitle: "Dip e trazioni assistite",
            category: .forza,
            rect: CGRect(x: 6.9, y: 242.4, width: 69.3, height: 34.6),
            muscles: ["Dorsali", "Pettorali", "Tricipiti", "Bicipiti"],
            howTo: [
                "Imposta il contrappeso: più carico selezioni, più l'esercizio è facilitato.",
                "Appoggia le ginocchia (o i piedi) sulla pedana assistita.",
                "Dip: gomiti indietro, scendi fino a 90° e risali.",
                "Chin-up: tira il petto verso la sbarra portando i gomiti in basso."
            ],
            tips: ["Sali e scendi dalla pedana solo con l'attrezzo a riposo."]
        ),
        GymMachine(
            id: "decline-press",
            name: "Decline press",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 97, y: 242.4, width: 55.4, height: 34.6),
            muscles: ["Pettorale basso", "Tricipiti"],
            howTo: [
                "Siediti con la schiena in appoggio e afferra le maniglie leggermente sotto la linea del petto.",
                "Spingi in avanti e verso il basso in modo controllato.",
                "Rientra fermandoti quando i gomiti superano di poco il tronco."
            ],
            tips: ["Se senti tirare la spalla, riduci l'escursione del ritorno."]
        ),
        GymMachine(
            id: "chest-incline-shoulder-press",
            name: "Chest / Incline / Shoulder press",
            subtitle: "Technogym — tre esercizi in uno",
            category: .forza,
            rect: CGRect(x: 256.2, y: 249.3, width: 55.4, height: 41.6),
            muscles: ["Pettorali", "Deltoidi", "Tricipiti"],
            howTo: [
                "Regola lo schienale alla posizione dell'esercizio desiderato: Chest press, Incline press o Shoulder press.",
                "Siediti con la schiena completamente in appoggio.",
                "Afferra le maniglie corrispondenti (posizione A, B o C indicata sulla targhetta).",
                "Spingi fino quasi all'estensione completa e torna controllato."
            ],
            tips: ["Lo schienale ha tre scatti: controlla di averlo bloccato prima di caricare."]
        ),
        GymMachine(
            id: "abdominal-crunch",
            name: "Abdominal crunch",
            subtitle: "FitActive",
            category: .forza,
            rect: CGRect(x: 318.6, y: 249.3, width: 55.4, height: 41.6),
            muscles: ["Addominali"],
            howTo: [
                "Regola l'altezza di seduta in modo che la parte alta della schiena poggi sul cuscinetto alto.",
                "Afferra le maniglie sopra le spalle.",
                "Fletti il busto in avanti avvicinando le costole al bacino.",
                "Risali lentamente senza rilasciare del tutto la tensione."
            ],
            tips: ["Il movimento è corto: non tirare con le braccia."]
        ),
        GymMachine(
            id: "stepmill",
            name: "Cardio salire scale",
            subtitle: "Stepmill / scala infinita",
            category: .cardio,
            rect: CGRect(x: 408.6, y: 270.1, width: 69.2, height: 34.6),
            muscles: ["Cardio", "Glutei", "Quadricipiti"],
            howTo: [
                "Sali quando i gradini sono fermi e tieni il corrimano finché non parti.",
                "Imposta una velocità che ti permetta di appoggiare tutto il piede sul gradino.",
                "Busto eretto, sguardo avanti: evita di appenderti al corrimano.",
                "Chiudi con 2-3 minuti a velocità bassa per defaticare."
            ],
            tips: ["Ottimo per il defaticamento a fine scheda."]
        ),
        GymMachine(
            id: "diverging-lat-pulldown",
            name: "Diverging lat pulldown",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 256.2, y: 297.8, width: 55.4, height: 41.5),
            muscles: ["Dorsali", "Bicipiti"],
            howTo: [
                "Regola il cuscinetto sulle cosce in modo da restare stabile.",
                "Afferra le maniglie divergenti e siediti con il busto leggermente indietro.",
                "Tira portando i gomiti verso il basso e le scapole in dentro.",
                "Risali accompagnando fino all'allungamento completo."
            ],
            tips: ["Il nome non era certo nel rilievo iniziale: verifica la targhetta in sede."],
            uncertain: true
        ),
        GymMachine(
            id: "low-row",
            name: "Low row",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 138.5, y: 304.7, width: 69.3, height: 34.6),
            muscles: ["Dorsali", "Romboidi", "Bicipiti"],
            howTo: [
                "Siediti con i piedi sulla pedana e le ginocchia leggermente piegate.",
                "Afferra l'impugnatura mantenendo la schiena neutra.",
                "Tira verso l'addome stringendo le scapole.",
                "Accompagna il ritorno lasciando allungare i dorsali, senza curvare la schiena."
            ],
            tips: ["Il busto resta quasi fermo: non usare lo slancio all'indietro."]
        ),
        GymMachine(
            id: "colonna-multi-4",
            name: "Colonna multifunzione (4 attrezzi)",
            subtitle: "Stazione a cavi",
            category: .cavi,
            rect: CGRect(x: 145.4, y: 328.9, width: 55.4, height: 55.4),
            muscles: ["Total body"],
            howTo: [
                "Colonna a quattro postazioni: scegli l'accessorio e aggancialo al moschettone.",
                "Imposta l'altezza della carrucola in base all'esercizio.",
                "Mantieni tensione costante sul cavo, sia in andata che al ritorno."
            ],
            tips: ["Riponi barre e maniglie sul supporto quando hai finito."]
        ),
        GymMachine(
            id: "lat-pulldown-2",
            name: "Lat pulldown",
            subtitle: "Postazione a parete",
            category: .forza,
            rect: CGRect(x: 0, y: 339.3, width: 69.2, height: 34.7),
            muscles: ["Dorsali", "Bicipiti"],
            howTo: [
                "Regola il cuscinetto sulle cosce e siediti bene fermo.",
                "Afferra la barra con presa larga.",
                "Tira la barra verso la parte alta del petto, gomiti in basso.",
                "Risali controllato fino alle braccia distese."
            ],
            tips: ["Non tirare dietro la nuca: sempre davanti al viso."]
        ),
        GymMachine(
            id: "lat-pulldown",
            name: "Lat pulldown",
            subtitle: nil,
            category: .forza,
            rect: CGRect(x: 138.5, y: 377.4, width: 69.3, height: 34.6),
            muscles: ["Dorsali", "Bicipiti"],
            howTo: [
                "Regola il cuscinetto sulle cosce e siediti bene fermo.",
                "Afferra la barra con presa larga.",
                "Tira la barra verso la parte alta del petto, gomiti in basso.",
                "Risali controllato fino alle braccia distese."
            ],
            tips: ["Non tirare dietro la nuca: sempre davanti al viso."]
        ),
        GymMachine(
            id: "colonna-multi-2",
            name: "Colonna multifunzione (2 attrezzi)",
            subtitle: "Stazione a cavi",
            category: .cavi,
            rect: CGRect(x: 97, y: 453.6, width: 55.4, height: 55.4),
            muscles: ["Total body"],
            howTo: [
                "Colonna a due postazioni: aggancia l'accessorio e imposta l'altezza della carrucola.",
                "Regola il carico con il perno e verifica che sia inserito a fondo.",
                "Mantieni tensione costante sul cavo."
            ],
            tips: ["Riponi barre e maniglie sul supporto quando hai finito."]
        ),
        GymMachine(
            id: "rematore",
            name: "Rematore",
            subtitle: "Vogatore / rowing machine",
            category: .cardio,
            rect: CGRect(x: 290.9, y: 547.1, width: 69.2, height: 34.6),
            muscles: ["Cardio", "Dorsali", "Gambe"],
            howTo: [
                "Regola i cinturini sui piedi e afferra l'impugnatura a braccia distese.",
                "Spingi prima con le gambe, poi apri il busto, infine tira con le braccia.",
                "Al ritorno inverti l'ordine: braccia, busto, gambe.",
                "Mantieni un ritmo regolare, senza strappi."
            ],
            tips: ["La potenza viene dalle gambe: le braccia arrivano per ultime."]
        ),
        GymMachine(
            id: "manubri",
            name: "Rastrelliera manubri",
            subtitle: "Zona pesi liberi",
            category: .liberi,
            rect: CGRect(x: 27.7, y: 554, width: 41.5, height: 110.8),
            muscles: ["Total body"],
            howTo: [
                "Scegli la coppia di manubri partendo dal peso più basso per il riscaldamento.",
                "Sollevali piegando le ginocchia, non la schiena.",
                "A fine serie rimettili al loro posto, ordinati per peso."
            ],
            tips: ["Squat, affondi e split squat della scheda di Maria Pia si fanno qui, con le panche a fianco."]
        )
    ]

    // MARK: - Attrezzi ripetuti (stessa scheda, più postazioni)

    private static let repeatedMachines: [GymMachine] = {
        var list: [GymMachine] = []

        // Panche declinate regolabili
        let panche: [(String, CGRect)] = [
            ("panca-declinata-1", CGRect(x: 290.9, y: 41.5, width: 55.4, height: 34.7)),
            ("panca-declinata-2", CGRect(x: 360.1, y: 41.5, width: 55.4, height: 34.7))
        ]
        for (index, item) in panche.enumerated() {
            list.append(GymMachine(
                id: item.0,
                name: "Panca declinata regolabile \(index + 1)",
                subtitle: "Con rulli fermapiedi",
                category: .liberi,
                rect: item.1,
                muscles: ["Addominali", "Flessori dell'anca"],
                howTo: [
                    "Regola l'inclinazione e blocca i piedi sotto i rulli.",
                    "Mani al petto o dietro la testa senza tirare il collo.",
                    "Sali arrotolando la colonna, espirando.",
                    "Scendi lentamente senza appoggiare del tutto le spalle."
                ],
                tips: ["La panca era marcata come non identificata nel rilievo iniziale: verifica la regolazione in sede."],
                uncertain: true
            ))
        }

        // Lateral raise
        let lateral: [(String, CGRect)] = [
            ("lateral-raise-1", CGRect(x: 256.2, y: 166.2, width: 55.4, height: 34.6)),
            ("lateral-raise-2", CGRect(x: 256.2, y: 207.8, width: 55.4, height: 34.6))
        ]
        for (index, item) in lateral.enumerated() {
            list.append(GymMachine(
                id: item.0,
                name: "Lateral raise \(index + 1)",
                subtitle: "FitActive",
                category: .forza,
                rect: item.1,
                muscles: ["Deltoidi laterali"],
                howTo: [
                    "Siedi con la schiena dritta e le spalle contro il cuscinetto.",
                    "Posiziona gli avambracci contro i cuscinetti e afferra le maniglie senza stringere.",
                    "Apri le braccia lateralmente fino all'altezza delle spalle.",
                    "Scendi lentamente senza far sbattere il pacco pesi."
                ],
                tips: ["Non superare la linea delle spalle: oltre entra il trapezio."]
            ))
        }

        // Adjustable pulley
        let pulley: [(String, CGRect)] = [
            ("adjustable-pulley-1", CGRect(x: 76.2, y: 339.3, width: 69.2, height: 34.7)),
            ("adjustable-pulley-2", CGRect(x: 197.4, y: 342.8, width: 69.2, height: 34.6)),
            ("adjustable-pulley-3", CGRect(x: 90, y: 429.4, width: 69.3, height: 34.6)),
            ("adjustable-pulley-4", CGRect(x: 90, y: 502.1, width: 69.3, height: 34.6))
        ]
        for (index, item) in pulley.enumerated() {
            list.append(GymMachine(
                id: item.0,
                name: "Adjustable pulley \(index + 1)",
                subtitle: "Cavo ad altezza regolabile",
                category: .cavi,
                rect: item.1,
                muscles: ["Bicipiti", "Tricipiti", "Adduttori", "Polpacci"],
                howTo: [
                    "Sblocca il carrello e porta la carrucola all'altezza dell'esercizio.",
                    "Tricipiti: carrucola in alto, gomiti fermi al fianco, estendi le braccia verso il basso.",
                    "Bicipiti: carrucola in basso, gomiti fermi, fletti l'avambraccio.",
                    "Adduzione anca e calf: cavigliera in basso, movimento lento e completo."
                ],
                tips: ["Blocca sempre il carrello prima di caricare."]
            ))
        }

        // Cyclette
        let bikes: [CGRect] = [
            CGRect(x: 290.9, y: 346.3, width: 69.2, height: 34.6),
            CGRect(x: 290.9, y: 380.9, width: 69.2, height: 34.6),
            CGRect(x: 290.9, y: 422.4, width: 69.2, height: 34.7),
            CGRect(x: 290.9, y: 457.1, width: 69.2, height: 34.6),
            CGRect(x: 290.9, y: 495.2, width: 69.2, height: 34.6)
        ]
        for (index, rect) in bikes.enumerated() {
            list.append(GymMachine(
                id: "cyclette-\(index + 1)",
                name: "Cyclette \(index + 1)",
                subtitle: nil,
                category: .cardio,
                rect: rect,
                muscles: ["Cardio", "Quadricipiti"],
                howTo: [
                    "Regola la sella: a pedale basso la gamba deve restare quasi distesa.",
                    "Imposta il livello di resistenza e parti con 2 minuti facili.",
                    "Mantieni una cadenza regolare, spalle rilassate.",
                    "Chiudi con qualche minuto a resistenza minima."
                ],
                tips: ["Ottima quando serve cardio a bassi battiti senza impatto."]
            ))
        }

        // Tapis roulant
        let treadmills: [CGRect] = [
            CGRect(x: 408.6, y: 311.6, width: 69.2, height: 34.7),
            CGRect(x: 408.6, y: 353.2, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 394.7, width: 69.2, height: 34.7),
            CGRect(x: 408.6, y: 436.3, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 484.8, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 526.3, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 567.9, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 609.4, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 651, width: 69.2, height: 34.6),
            CGRect(x: 408.6, y: 692.5, width: 69.2, height: 34.7)
        ]
        for (index, rect) in treadmills.enumerated() {
            list.append(GymMachine(
                id: "tapis-\(index + 1)",
                name: "Tapis roulant \(index + 1)",
                subtitle: nil,
                category: .cardio,
                rect: rect,
                muscles: ["Cardio"],
                howTo: [
                    "Aggancia la clip di sicurezza prima di partire.",
                    "Sali con i piedi ai lati del nastro e avvia a velocità bassa.",
                    "Per il lavoro in pendenza imposta l'inclinazione e tieni 5-6 km/h.",
                    "Riduci gradualmente prima di fermarti, senza saltare giù."
                ],
                tips: ["Cammina al centro del nastro senza appoggiarti alle maniglie."]
            ))
        }

        // Panche
        list.append(GymMachine(
            id: "panche",
            name: "Panche regolabili (x6)",
            subtitle: "Zona pesi liberi",
            category: .liberi,
            rect: CGRect(x: 90, y: 574.8, width: 69.3, height: 34.6),
            muscles: ["Total body"],
            howTo: [
                "Regola lo schienale con il perno: piano, inclinato o verticale.",
                "Verifica che il perno sia inserito a fondo prima di sederti.",
                "A fine serie riporta la panca in posizione piana."
            ],
            tips: ["Sei panche a disposizione, a fianco della rastrelliera manubri."]
        ))

        // Ellittiche
        let ellittiche: [CGRect] = [
            CGRect(x: 290.9, y: 588.6, width: 69.2, height: 34.7),
            CGRect(x: 290.9, y: 630.2, width: 69.2, height: 34.6)
        ]
        for (index, rect) in ellittiche.enumerated() {
            list.append(GymMachine(
                id: "ellittica-\(index + 1)",
                name: "Ellittica \(index + 1)",
                subtitle: "Cross trainer",
                category: .cardio,
                rect: rect,
                muscles: ["Cardio", "Total body"],
                howTo: [
                    "Sali appoggiando prima un piede sulla pedana bassa.",
                    "Imposta resistenza bassa e trova un movimento fluido.",
                    "Spingi e tira anche con le braccia per coinvolgere tutto il corpo.",
                    "Mantieni il busto eretto, senza appoggiare il peso sulle maniglie fisse."
                ],
                tips: ["Zero impatto sulle articolazioni: ideale come riscaldamento."]
            ))
        }

        return list
    }()

    // MARK: - Collegamento scheda ↔ attrezzo

    /// Attrezzi su cui si svolge un esercizio della scheda.
    /// Le chiavi sono le `query` usate in `RoutineData`.
    private static let queryToMachines: [String: [String]] = [
        "walk elliptical cross trainer": ["ellittica-1", "ellittica-2"],
        "walking on incline treadmill": (1...10).map { "tapis-\($0)" },
        "walking on stepmill": ["stepmill"],
        "stationary bike run": (1...5).map { "cyclette-\($0)" },
        "lever chest press": ["converging-chest-press", "chest-incline-shoulder-press"],
        "lever seated fly": ["rear-delt-pec-fly"],
        "lever military press": ["chest-incline-shoulder-press"],
        "lever lateral raise": ["lateral-raise-1", "lateral-raise-2"],
        "assisted triceps dip (kneeling)": ["dip-chin-assist"],
        "lever assisted chin-up": ["dip-chin-assist"],
        "lever seated row": ["seated-row", "diverging-seated-row", "low-row"],
        "lever seated hip adduction": ["hip-adductor-abductor"],
        "lever seated hip abduction": ["hip-adductor-abductor"],
        "lever lying leg curl": ["prone-leg-curl", "leg-curl-extension"],
        "lever leg extension": ["leg-curl-extension"],
        "lever alternate leg press": ["leg-press"],
        "lever bicep curl": ["adjustable-pulley-1", "adjustable-pulley-2", "adjustable-pulley-3", "adjustable-pulley-4"],
        "cable hip adduction": ["adjustable-pulley-1", "adjustable-pulley-2", "adjustable-pulley-3", "adjustable-pulley-4"],
        "cable standing calf raise": ["adjustable-pulley-1", "adjustable-pulley-2", "adjustable-pulley-3", "adjustable-pulley-4"],
        "dumbbell goblet squat": ["manubri"],
        "dumbbell lunge": ["manubri"],
        "dumbbell squat": ["manubri"],
        "dumbbell plyo squat": ["manubri"],
        "dumbbell single leg split squat": ["manubri", "panche"],
        "bodyweight drop jump squat": ["area-corpo-libero"],
        "curtsey squat": ["area-corpo-libero"],
        "side plank hip adduction": ["area-corpo-libero"]
    ]

    /// Gli attrezzi della sala su cui si può fare quell'esercizio della scheda.
    static func machines(for query: String) -> [GymMachine] {
        let key = query.lowercased()
        if let ids = queryToMachines[key] {
            return ids.compactMap { machine(id: $0) }
        }
        return fallbackMachines(for: key)
    }

    /// Se la scheda cambia e compare una query non mappata, si prova a indovinare
    /// dall'attrezzo citato nel nome dell'esercizio.
    private static func fallbackMachines(for key: String) -> [GymMachine] {
        if key.contains("treadmill") { return (1...10).compactMap { machine(id: "tapis-\($0)") } }
        if key.contains("bike") { return (1...5).compactMap { machine(id: "cyclette-\($0)") } }
        if key.contains("elliptical") { return [machine(id: "ellittica-1"), machine(id: "ellittica-2")].compactMap { $0 } }
        if key.contains("stepmill") || key.contains("stair") { return [machine(id: "stepmill")].compactMap { $0 } }
        if key.contains("row") { return [machine(id: "seated-row")].compactMap { $0 } }
        if key.contains("pulldown") { return [machine(id: "lat-pulldown")].compactMap { $0 } }
        if key.contains("cable") { return [machine(id: "adjustable-pulley-1")].compactMap { $0 } }
        if key.contains("dumbbell") { return [machine(id: "manubri")].compactMap { $0 } }
        if key.contains("leg press") { return [machine(id: "leg-press")].compactMap { $0 } }
        if key.contains("body weight") || key.contains("bodyweight") { return [machine(id: "area-corpo-libero")].compactMap { $0 } }
        return []
    }
}
