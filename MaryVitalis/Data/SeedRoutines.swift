import Foundation

/// Una scheda scritta a mano nel codice. Non è più il modello dell'app: serve
/// solo come sorgente per la migrazione dei dati storici e come punto di
/// partenza offerto a chi installa l'app senza sapere da dove cominciare.
struct SeedRoutine {
    let id: String
    let name: String
    let emoji: String
    let accentHex: String
    let goal: String
    let summary: String
    let meta: [String]
    let days: [SeedDay]
}

struct SeedDay {
    let name: String
    let exercises: [SeedExercise]
}

struct SeedExercise {
    let query: String
    /// Formato storico: "4 serie x 12 ripetizioni" oppure "10 min - Ritmo leggero".
    /// Viene interpretato da `Plan` una sola volta, in fase di migrazione.
    let details: String
}

/// Le schede: stessi contenuti dell'array `ROUTINES` della SPA.
enum RoutineData {
    static let all: [SeedRoutine] = [samuel, raffaele, mariapia]

    static func seed(id: String) -> SeedRoutine? { all.first { $0.id == id } }

    static let samuel = SeedRoutine(
        id: "samuel",
        name: "Samuel",
        emoji: "🛡️",
        accentHex: "#38bdf8",
        goal: "Recupero lombare",
        summary: "Protocollo in 3 sedute da 1h 15m costruito sulla sicurezza della colonna dopo l'intervento: nessun carico assiale, tanto lavoro guidato alle macchine.",
        meta: ["3 giorni / settimana", "~1h 15m", "Livello: base"],
        days: [
            SeedDay(name: "Petto, Spalle, Tricipiti e Cardio", exercises: [
                SeedExercise(query: "walk elliptical cross trainer", details: "10 min - Ritmo moderato"),
                SeedExercise(query: "lever chest press", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "lever seated fly", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "lever military press", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "lever lateral raise", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "assisted triceps dip (kneeling)", details: "3 serie x 12 ripetizioni"),
                SeedExercise(query: "walking on incline treadmill", details: "15-20 min - 5-6 km/h (Pendenza)")
            ]),
            SeedDay(name: "Dorso, Bicipiti, Tonificazione Gambe", exercises: [
                SeedExercise(query: "stationary bike run", details: "10 min - Ritmo leggero"),
                SeedExercise(query: "lever seated row", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "lever assisted chin-up", details: "3 serie x 10 ripetizioni"),
                SeedExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni (Movimento lento)"),
                SeedExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni (Movimento lento)"),
                SeedExercise(query: "lever lying leg curl", details: "4 serie x 15 ripetizioni"),
                SeedExercise(query: "walking on stepmill", details: "15-20 min - Defaticamento scale")
            ]),
            SeedDay(name: "Total Body e Maxi-Cardio", exercises: [
                SeedExercise(query: "walking on stepmill", details: "10 min - Riscaldamento scale"),
                SeedExercise(query: "lever alternate leg press", details: "3 serie x 20 ripetizioni"),
                SeedExercise(query: "lever chest press", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "lever seated row", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "lever leg extension", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "lever bicep curl", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "walking on incline treadmill", details: "30 min - Maxi Cardio in pendenza")
            ])
        ]
    )

    static let raffaele = SeedRoutine(
        id: "raffaele",
        name: "Raffaele",
        emoji: "🚀",
        accentHex: "#a78bfa",
        goal: "Ricondizionamento",
        summary: "Rientro graduale all'attività con priorità al ripristino articolare e al cardio a bassi battiti. Carichi contenuti, esecuzione lenta e controllata.",
        meta: ["3 giorni / settimana", "~1h 15m", "Livello: base"],
        days: [
            SeedDay(name: "Upper Body e Cardio Base", exercises: [
                SeedExercise(query: "stationary bike run", details: "10 min - Ritmo blando (Riscaldamento)"),
                SeedExercise(query: "lever seated row", details: "3 serie x 15 ripetizioni (Lento e controllato)"),
                SeedExercise(query: "lever chest press", details: "3 serie x 12 ripetizioni (Schiena in appoggio)"),
                SeedExercise(query: "lever lateral raise", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "lever bicep curl", details: "3 serie x 12 ripetizioni"),
                SeedExercise(query: "stationary bike run", details: "20 min - Ritmo costante, battiti bassi (Cardio)")
            ]),
            SeedDay(name: "Gambe, Core e Recupero Attivo", exercises: [
                SeedExercise(query: "walk elliptical cross trainer", details: "10 min - Movimento fluido (Riscaldamento)"),
                SeedExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni (Zero stress ginocchio)"),
                SeedExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni"),
                SeedExercise(query: "lever leg extension", details: "3 serie x 12 ripetizioni (Carico leggero)"),
                SeedExercise(query: "lever lying leg curl", details: "3 serie x 12 ripetizioni"),
                SeedExercise(query: "walk elliptical cross trainer", details: "20 min - Defaticante (Cardio)")
            ]),
            SeedDay(name: "Total Body Reconditioning", exercises: [
                SeedExercise(query: "stationary bike run", details: "10 min - Riscaldamento"),
                SeedExercise(query: "lever seated fly", details: "3 serie x 15 ripetizioni (Apertura toracica)"),
                SeedExercise(query: "lever military press", details: "3 serie x 12 ripetizioni (Schiena supportata)"),
                SeedExercise(query: "lever alternate leg press", details: "3 serie x 15 rep per gamba (Carico piuma!)"),
                SeedExercise(query: "assisted triceps dip (kneeling)", details: "3 serie x 12 ripetizioni"),
                SeedExercise(query: "stationary bike run", details: "25 min - Spinta metabolica (Cardio)")
            ])
        ]
    )

    static let mariapia = SeedRoutine(
        id: "mariapia",
        name: "Maria Pia",
        emoji: "🔥",
        accentHex: "#fb7185",
        goal: "Tonificazione gambe",
        summary: "Tre sedute a intensità medio-alta dedicate a gambe, glutei e interno coscia, pensate per affiancare il corso di GAG senza sovraccaricare.",
        meta: ["3 giorni / settimana", "~1h", "Livello: intermedio"],
        days: [
            SeedDay(name: "Focus Interno Coscia e Quadricipiti", exercises: [
                SeedExercise(query: "walking on incline treadmill", details: "10 min - Riscaldamento in pendenza"),
                SeedExercise(query: "lever seated hip adduction", details: "4 serie x 15-20 ripetizioni (Movimento controllato)"),
                SeedExercise(query: "cable hip adduction", details: "3 serie x 15 ripetizioni per gamba"),
                SeedExercise(query: "dumbbell goblet squat", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "dumbbell lunge", details: "3 serie x 12 ripetizioni per gamba"),
                SeedExercise(query: "lever leg extension", details: "3 serie x 15 ripetizioni"),
                SeedExercise(query: "bodyweight drop jump squat", details: "3 serie x 45 secondi (Alta intensità)")
            ]),
            SeedDay(name: "Catena Posteriore e Glutei", exercises: [
                SeedExercise(query: "walk elliptical cross trainer", details: "10 min - Riscaldamento (Ellittica)"),
                SeedExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni"),
                SeedExercise(query: "lever lying leg curl", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "dumbbell single leg split squat", details: "3 serie x 10 ripetizioni per gamba"),
                SeedExercise(query: "curtsey squat", details: "3 serie x 15 ripetizioni per lato"),
                SeedExercise(query: "cable standing calf raise", details: "4 serie x 15 ripetizioni"),
                SeedExercise(query: "walking on stepmill", details: "15 min - Defaticamento scale")
            ]),
            SeedDay(name: "Total Leg Circuit (Alta Intensità)", exercises: [
                SeedExercise(query: "stationary bike run", details: "5 min - Riscaldamento"),
                SeedExercise(query: "side plank hip adduction", details: "3 serie x 12 ripetizioni per lato"),
                SeedExercise(query: "lever alternate leg press", details: "4 serie x 15 ripetizioni"),
                SeedExercise(query: "dumbbell squat", details: "4 serie x 12 ripetizioni"),
                SeedExercise(query: "dumbbell plyo squat", details: "3 serie x 12 ripetizioni (Esplosivi)"),
                SeedExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni"),
                SeedExercise(query: "walking on incline treadmill", details: "20 min - Maxi Cardio in pendenza")
            ])
        ]
    )
}
