import Foundation

/// Le schede: stessi contenuti dell'array `ROUTINES` della SPA.
enum RoutineData {
    static let all: [Routine] = [samuel, raffaele, mariapia]

    static func routine(id: String) -> Routine? { all.first { $0.id == id } }

    static let samuel = Routine(
        id: "samuel",
        name: "Samuel",
        emoji: "🛡️",
        accentHex: "#38bdf8",
        goal: "Recupero lombare",
        summary: "Protocollo in 3 sedute da 1h 15m costruito sulla sicurezza della colonna dopo l'intervento: nessun carico assiale, tanto lavoro guidato alle macchine.",
        meta: ["3 giorni / settimana", "~1h 15m", "Livello: base"],
        days: [
            RoutineDay(name: "Petto, Spalle, Tricipiti e Cardio", exercises: [
                RoutineExercise(query: "walk elliptical cross trainer", details: "10 min - Ritmo moderato"),
                RoutineExercise(query: "lever chest press", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "lever seated fly", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "lever military press", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "lever lateral raise", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "assisted triceps dip (kneeling)", details: "3 serie x 12 ripetizioni"),
                RoutineExercise(query: "walking on incline treadmill", details: "15-20 min - 5-6 km/h (Pendenza)")
            ]),
            RoutineDay(name: "Dorso, Bicipiti, Tonificazione Gambe", exercises: [
                RoutineExercise(query: "stationary bike run", details: "10 min - Ritmo leggero"),
                RoutineExercise(query: "lever seated row", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "lever assisted chin-up", details: "3 serie x 10 ripetizioni"),
                RoutineExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni (Movimento lento)"),
                RoutineExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni (Movimento lento)"),
                RoutineExercise(query: "lever lying leg curl", details: "4 serie x 15 ripetizioni"),
                RoutineExercise(query: "walking on stepmill", details: "15-20 min - Defaticamento scale")
            ]),
            RoutineDay(name: "Total Body e Maxi-Cardio", exercises: [
                RoutineExercise(query: "walking on stepmill", details: "10 min - Riscaldamento scale"),
                RoutineExercise(query: "lever alternate leg press", details: "3 serie x 20 ripetizioni"),
                RoutineExercise(query: "lever chest press", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "lever seated row", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "lever leg extension", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "lever bicep curl", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "walking on incline treadmill", details: "30 min - Maxi Cardio in pendenza")
            ])
        ]
    )

    static let raffaele = Routine(
        id: "raffaele",
        name: "Raffaele",
        emoji: "🚀",
        accentHex: "#a78bfa",
        goal: "Ricondizionamento",
        summary: "Rientro graduale all'attività con priorità al ripristino articolare e al cardio a bassi battiti. Carichi contenuti, esecuzione lenta e controllata.",
        meta: ["3 giorni / settimana", "~1h 15m", "Livello: base"],
        days: [
            RoutineDay(name: "Upper Body e Cardio Base", exercises: [
                RoutineExercise(query: "stationary bike run", details: "10 min - Ritmo blando (Riscaldamento)"),
                RoutineExercise(query: "lever seated row", details: "3 serie x 15 ripetizioni (Lento e controllato)"),
                RoutineExercise(query: "lever chest press", details: "3 serie x 12 ripetizioni (Schiena in appoggio)"),
                RoutineExercise(query: "lever lateral raise", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "lever bicep curl", details: "3 serie x 12 ripetizioni"),
                RoutineExercise(query: "stationary bike run", details: "20 min - Ritmo costante, battiti bassi (Cardio)")
            ]),
            RoutineDay(name: "Gambe, Core e Recupero Attivo", exercises: [
                RoutineExercise(query: "walk elliptical cross trainer", details: "10 min - Movimento fluido (Riscaldamento)"),
                RoutineExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni (Zero stress ginocchio)"),
                RoutineExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni"),
                RoutineExercise(query: "lever leg extension", details: "3 serie x 12 ripetizioni (Carico leggero)"),
                RoutineExercise(query: "lever lying leg curl", details: "3 serie x 12 ripetizioni"),
                RoutineExercise(query: "walk elliptical cross trainer", details: "20 min - Defaticante (Cardio)")
            ]),
            RoutineDay(name: "Total Body Reconditioning", exercises: [
                RoutineExercise(query: "stationary bike run", details: "10 min - Riscaldamento"),
                RoutineExercise(query: "lever seated fly", details: "3 serie x 15 ripetizioni (Apertura toracica)"),
                RoutineExercise(query: "lever military press", details: "3 serie x 12 ripetizioni (Schiena supportata)"),
                RoutineExercise(query: "lever alternate leg press", details: "3 serie x 15 rep per gamba (Carico piuma!)"),
                RoutineExercise(query: "assisted triceps dip (kneeling)", details: "3 serie x 12 ripetizioni"),
                RoutineExercise(query: "stationary bike run", details: "25 min - Spinta metabolica (Cardio)")
            ])
        ]
    )

    static let mariapia = Routine(
        id: "mariapia",
        name: "Maria Pia",
        emoji: "🔥",
        accentHex: "#fb7185",
        goal: "Tonificazione gambe",
        summary: "Tre sedute a intensità medio-alta dedicate a gambe, glutei e interno coscia, pensate per affiancare il corso di GAG senza sovraccaricare.",
        meta: ["3 giorni / settimana", "~1h", "Livello: intermedio"],
        days: [
            RoutineDay(name: "Focus Interno Coscia e Quadricipiti", exercises: [
                RoutineExercise(query: "walking on incline treadmill", details: "10 min - Riscaldamento in pendenza"),
                RoutineExercise(query: "lever seated hip adduction", details: "4 serie x 15-20 ripetizioni (Movimento controllato)"),
                RoutineExercise(query: "cable hip adduction", details: "3 serie x 15 ripetizioni per gamba"),
                RoutineExercise(query: "dumbbell goblet squat", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "dumbbell lunge", details: "3 serie x 12 ripetizioni per gamba"),
                RoutineExercise(query: "lever leg extension", details: "3 serie x 15 ripetizioni"),
                RoutineExercise(query: "bodyweight drop jump squat", details: "3 serie x 45 secondi (Alta intensità)")
            ]),
            RoutineDay(name: "Catena Posteriore e Glutei", exercises: [
                RoutineExercise(query: "walk elliptical cross trainer", details: "10 min - Riscaldamento (Ellittica)"),
                RoutineExercise(query: "lever seated hip adduction", details: "3 serie x 20 ripetizioni"),
                RoutineExercise(query: "lever lying leg curl", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "dumbbell single leg split squat", details: "3 serie x 10 ripetizioni per gamba"),
                RoutineExercise(query: "curtsey squat", details: "3 serie x 15 ripetizioni per lato"),
                RoutineExercise(query: "cable standing calf raise", details: "4 serie x 15 ripetizioni"),
                RoutineExercise(query: "walking on stepmill", details: "15 min - Defaticamento scale")
            ]),
            RoutineDay(name: "Total Leg Circuit (Alta Intensità)", exercises: [
                RoutineExercise(query: "stationary bike run", details: "5 min - Riscaldamento"),
                RoutineExercise(query: "side plank hip adduction", details: "3 serie x 12 ripetizioni per lato"),
                RoutineExercise(query: "lever alternate leg press", details: "4 serie x 15 ripetizioni"),
                RoutineExercise(query: "dumbbell squat", details: "4 serie x 12 ripetizioni"),
                RoutineExercise(query: "dumbbell plyo squat", details: "3 serie x 12 ripetizioni (Esplosivi)"),
                RoutineExercise(query: "lever seated hip abduction", details: "3 serie x 20 ripetizioni"),
                RoutineExercise(query: "walking on incline treadmill", details: "20 min - Maxi Cardio in pendenza")
            ])
        ]
    )
}
