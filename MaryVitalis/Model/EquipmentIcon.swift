import Foundation

/// Le icone degli attrezzi, disegnate **di profilo**.
///
/// Quelle di prima erano piante viste dall'alto: a quaranta punti un leg press
/// dall'alto e una panca dall'alto sono lo stesso rettangolo. Di profilo un
/// attrezzo si riconosce dalla sagoma — la ruota della cyclette, il piano
/// inclinato del leg press, il nastro del tapis — ed è così che lo si cerca con
/// gli occhi in una sala.
///
/// Sono tracciati, non immagini: si ridimensionano senza sfocare, cambiano
/// colore con la categoria e non portano licenze dietro.
enum EquipmentIcon: String, CaseIterable, Identifiable {
    case treadmill, bike, elliptical, stepper, rower
    case legPress, hackSquat, legExtension, legCurl, abductor, glute, hipThrust, calf
    case chestPress, shoulderPress, pecFly, lateralRaise
    case latPulldown, seatedRow, pullover
    case cableColumn, smithMachine, dipAssist
    case abCrunch, backExtension
    case bench, benchRack, dumbbellRack, plateRack, kettlebell
    case platform, mat, stretchArea
    case unknown

    var id: String { rawValue }

    /// Il nome per l'elenco di scelta.
    var title: String {
        switch self {
        case .treadmill: "Tapis roulant"
        case .bike: "Cyclette"
        case .elliptical: "Ellittica"
        case .stepper: "Stair climber"
        case .rower: "Vogatore"
        case .legPress: "Leg press"
        case .hackSquat: "Hack squat"
        case .legExtension: "Leg extension"
        case .legCurl: "Leg curl"
        case .abductor: "Adduttori / abduttori"
        case .glute: "Glutei"
        case .hipThrust: "Hip thrust"
        case .calf: "Polpacci"
        case .chestPress: "Chest press"
        case .shoulderPress: "Shoulder press"
        case .pecFly: "Pectoral fly"
        case .lateralRaise: "Alzate laterali"
        case .latPulldown: "Lat machine"
        case .seatedRow: "Pulley / rematore"
        case .pullover: "Pullover"
        case .cableColumn: "Colonna cavi"
        case .smithMachine: "Multipower"
        case .dipAssist: "Dip / trazioni assistite"
        case .abCrunch: "Addominali"
        case .backExtension: "Lombari"
        case .bench: "Panca"
        case .benchRack: "Panca con rack"
        case .dumbbellRack: "Rastrelliera manubri"
        case .plateRack: "Dischi"
        case .kettlebell: "Kettlebell"
        case .platform: "Pedana"
        case .mat: "Tappetino"
        case .stretchArea: "Area stretching"
        case .unknown: "Da identificare"
        }
    }

    /// Le famiglie, per l'elenco di scelta.
    static let groups: [(String, [EquipmentIcon])] = [
        ("Cardio", [.treadmill, .bike, .elliptical, .stepper, .rower]),
        ("Gambe", [.legPress, .hackSquat, .legExtension, .legCurl, .abductor,
                   .glute, .hipThrust, .calf]),
        ("Spinta", [.chestPress, .shoulderPress, .pecFly, .lateralRaise]),
        ("Tirata", [.latPulldown, .seatedRow, .pullover, .dipAssist]),
        ("Cavi e castelli", [.cableColumn, .smithMachine]),
        ("Core", [.abCrunch, .backExtension]),
        ("Pesi liberi", [.bench, .benchRack, .dumbbellRack, .plateRack, .kettlebell]),
        ("Spazi", [.platform, .mat, .stretchArea, .unknown])
    ]

    /// Indovina l'icona da quello che si sa dell'attrezzo. Serve al catalogo,
    /// che di icone non ne ha mai scelte, e come proposta a chi ne crea uno.
    static func guessed(id: String = "", name: String, muscles: [String] = []) -> EquipmentIcon {
        let key = (id + " " + name).lowercased()
        let muscle = muscles.joined(separator: " ").lowercased()

        if key.contains("tapis") || key.contains("treadmill") { return .treadmill }
        if key.contains("cyclette") || key.contains("bike") || key.contains("spin") { return .bike }
        if key.contains("ellittica") || key.contains("elliptical") || key.contains("cross") { return .elliptical }
        if key.contains("stepmill") || key.contains("scale") || key.contains("stair") || key.contains("step") { return .stepper }
        if key.contains("vogatore") || key.contains("rower") || key.contains("remo") { return .rower }

        if key.contains("hack") { return .hackSquat }
        if key.contains("leg press") || key.contains("pressa") { return .legPress }
        if key.contains("extension") && key.contains("leg") { return .legExtension }
        if key.contains("curl") && (key.contains("leg") || key.contains("femoral")) { return .legCurl }
        if key.contains("adduct") || key.contains("abduct") || key.contains("hip-ad") { return .abductor }
        if key.contains("glute") { return .glute }
        if key.contains("thrust") { return .hipThrust }
        if key.contains("calf") || key.contains("polpacc") { return .calf }

        if key.contains("chest press") || key.contains("converging") { return .chestPress }
        if key.contains("shoulder") || key.contains("military") { return .shoulderPress }
        if key.contains("fly") || key.contains("pec") || key.contains("delt") { return .pecFly }
        if key.contains("lateral") { return .lateralRaise }

        if key.contains("pulldown") || key.contains("lat ") || key.contains("lat-") { return .latPulldown }
        if key.contains("row") || key.contains("pulley") { return .seatedRow }
        if key.contains("pullover") { return .pullover }
        // "chin" da solo pescava "macchina", e "mat" pescava "matrix": le
        // parole corte cercate dentro altre parole trovano quello che vogliono.
        if key.contains("trazion") || key.contains("chin-up") || key.contains("chin up")
            || key.contains("dip/") || key.contains("dip ") || key.hasSuffix("dip") { return .dipAssist }

        if key.contains("colonna") || key.contains("cable") || key.contains("cavi") { return .cableColumn }
        if key.contains("multipower") || key.contains("smith") || key.contains("castello") { return .smithMachine }

        if key.contains("crunch") || key.contains("addominal") || key.contains("abdominal") { return .abCrunch }
        if key.contains("lombar") || key.contains("back extension") || key.contains("iperest") { return .backExtension }

        if key.contains("manubri") || key.contains("dumbbell") { return .dumbbellRack }
        if key.contains("disc") || key.contains("plate") || key.contains("bilancier") { return .plateRack }
        if key.contains("kettlebell") { return .kettlebell }
        if key.contains("panca") || key.contains("bench") { return key.contains("rack") ? .benchRack : .bench }

        if key.contains("pedana") || key.contains("vibrant") { return .platform }
        if key.contains("tappetin") || key.contains("materassin") { return .mat }
        if key.contains("stretch") || key.contains("corpo libero") || key.contains("funzional") { return .stretchArea }

        if muscle.contains("quadricipit") || muscle.contains("gambe") { return .legPress }
        if muscle.contains("pettoral") { return .chestPress }
        if muscle.contains("dorsal") || muscle.contains("schiena") { return .seatedRow }
        if muscle.contains("addominal") { return .abCrunch }
        return .unknown
    }
}
