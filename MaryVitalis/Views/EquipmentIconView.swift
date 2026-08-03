import SwiftUI

/// Disegna un'icona attrezzo dentro lo spazio che le viene dato.
struct EquipmentIconView: View {
    let icon: EquipmentIcon
    var tint: Color = Theme.textDim
    /// Spessore del tratto rispetto al lato: le icone piccole vogliono un
    /// tratto proporzionalmente più grosso, altrimenti scompaiono.
    var weight: CGFloat = 0.07

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let side = min(size.width, size.height)
            let frame = CGRect(x: (size.width - side) / 2,
                               y: (size.height - side) / 2,
                               width: side, height: side).insetBy(dx: side * 0.08,
                                                                  dy: side * 0.08)
            var drawing = IconDrawing(frame: frame,
                                      line: max(1.2, side * weight),
                                      tint: tint,
                                      context: context)
            drawing.draw(icon)
            context = drawing.context
        }
        .accessibilityHidden(true)
    }
}

/// Il pennello: coordinate da 0 a 1 dentro il riquadro, così ogni icona si
/// descrive come se fosse su un foglio quadrato.
private struct IconDrawing {
    let frame: CGRect
    let line: CGFloat
    let tint: Color
    var context: GraphicsContext

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y)
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y,
               width: frame.width * w, height: frame.height * h)
    }

    private mutating func stroke(_ path: Path, opacity: Double = 1, dash: [CGFloat] = []) {
        context.stroke(path, with: .color(tint.opacity(opacity)),
                       style: StrokeStyle(lineWidth: line, lineCap: .round,
                                          lineJoin: .round, dash: dash))
    }

    private mutating func fill(_ path: Path, opacity: Double = 1) {
        context.fill(path, with: .color(tint.opacity(opacity)))
    }

    private mutating func line(_ x1: CGFloat, _ y1: CGFloat,
                               _ x2: CGFloat, _ y2: CGFloat, opacity: Double = 1) {
        var path = Path()
        path.move(to: point(x1, y1))
        path.addLine(to: point(x2, y2))
        stroke(path, opacity: opacity)
    }

    private mutating func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                              radius: CGFloat = 0.03, opacity: Double = 1) {
        let path = Path(roundedRect: rect(x, y, w, h),
                        cornerRadius: frame.width * radius)
        fill(path, opacity: opacity)
    }

    private mutating func hollow(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                                 radius: CGFloat = 0.04, opacity: Double = 1) {
        let path = Path(roundedRect: rect(x, y, w, h),
                        cornerRadius: frame.width * radius)
        stroke(path, opacity: opacity)
    }

    private mutating func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                                 filled: Bool = false, opacity: Double = 1) {
        let box = rect(cx - r, cy - r, r * 2, r * 2)
        let path = Path(ellipseIn: box)
        if filled { fill(path, opacity: opacity) } else { stroke(path, opacity: opacity) }
    }

    /// Il pavimento: quasi tutte le sagome poggiano sulla stessa linea, ed è
    /// quello che le fa leggere come oggetti in una stanza.
    private mutating func floor(from: CGFloat = 0.05, to: CGFloat = 0.95) {
        line(from, 0.93, to, 0.93, opacity: 0.45)
    }

    mutating func draw(_ icon: EquipmentIcon) {
        switch icon {
        case .treadmill:
            floor()
            bar(0.06, 0.70, 0.62, 0.10, radius: 0.05)          // nastro, lungo e basso
            line(0.10, 0.75, 0.64, 0.75, opacity: 0.45)         // il tappeto che scorre
            line(0.66, 0.72, 0.82, 0.26)                        // montante inclinato
            hollow(0.70, 0.12, 0.26, 0.18, radius: 0.05)        // console
            circle(0.12, 0.86, 0.045)
            circle(0.62, 0.86, 0.045)

        case .bike:
            floor()
            circle(0.24, 0.72, 0.18)
            circle(0.78, 0.78, 0.11)
            line(0.24, 0.72, 0.52, 0.40)
            line(0.52, 0.40, 0.78, 0.78)
            line(0.52, 0.40, 0.66, 0.36)                        // sella
            line(0.52, 0.40, 0.44, 0.16)                        // piantone
            line(0.34, 0.16, 0.54, 0.16)                        // manubrio

        case .elliptical:
            floor()
            circle(0.22, 0.62, 0.14)                            // volano dietro
            line(0.22, 0.62, 0.86, 0.78)                        // braccio pedale, lungo e basso
            bar(0.70, 0.78, 0.22, 0.06, radius: 0.03)           // pedana
            line(0.22, 0.62, 0.22, 0.88)                        // colonna a terra
            line(0.22, 0.48, 0.22, 0.16)                        // montante alto
            line(0.10, 0.20, 0.34, 0.20)                        // manubrio fisso

        case .stepper:
            floor()
            var steps = Path()
            steps.move(to: point(0.10, 0.88))
            for index in 0..<4 {
                let x = 0.10 + CGFloat(index) * 0.18
                let y = 0.88 - CGFloat(index) * 0.16
                steps.addLine(to: point(x + 0.18, y))
                steps.addLine(to: point(x + 0.18, y - 0.16))
            }
            stroke(steps)
            line(0.86, 0.22, 0.86, 0.62)                        // corrimano

        case .rower:
            floor()
            line(0.14, 0.80, 0.92, 0.80)                        // rotaia lunga
            circle(0.20, 0.58, 0.15)                            // volano
            line(0.20, 0.58, 0.20, 0.80)
            bar(0.52, 0.71, 0.18, 0.07, radius: 0.03)           // sedile scorrevole
            line(0.34, 0.58, 0.50, 0.62, opacity: 0.7)          // catena
            line(0.30, 0.54, 0.30, 0.66)                        // maniglia
            bar(0.84, 0.66, 0.08, 0.14, radius: 0.03)           // poggiapiedi

        case .legPress:
            floor()
            line(0.10, 0.86, 0.62, 0.86)                        // base
            line(0.16, 0.86, 0.72, 0.24)                        // slitta inclinata
            bar(0.60, 0.16, 0.28, 0.10, radius: 0.03)           // piano d'appoggio
            bar(0.10, 0.60, 0.22, 0.09, radius: 0.03)           // schienale
            line(0.10, 0.69, 0.10, 0.86)

        case .hackSquat:
            floor()
            line(0.12, 0.88, 0.86, 0.88)
            line(0.24, 0.88, 0.80, 0.20)                        // rotaia
            bar(0.60, 0.34, 0.24, 0.08, radius: 0.03)           // spalliere
            line(0.36, 0.70, 0.52, 0.70)                        // pedana

        case .legExtension:
            floor()
            bar(0.14, 0.58, 0.32, 0.08, radius: 0.03)           // seduta
            bar(0.14, 0.30, 0.08, 0.28, radius: 0.03)           // schienale alto
            line(0.24, 0.66, 0.24, 0.90)
            line(0.42, 0.66, 0.42, 0.90)
            line(0.46, 0.66, 0.74, 0.52)                        // leva che sale
            circle(0.80, 0.48, 0.09, filled: true, opacity: 0.9) // rullo caviglie
            var arc = Path()                                     // il movimento
            arc.addArc(center: point(0.46, 0.66), radius: frame.width * 0.34,
                       startAngle: .degrees(-8), endAngle: .degrees(-34), clockwise: true)
            stroke(arc, opacity: 0.4, dash: [line, line * 1.4])

        case .legCurl:
            floor()
            bar(0.10, 0.48, 0.50, 0.09, radius: 0.04)           // panca prona
            line(0.18, 0.57, 0.18, 0.90)
            line(0.52, 0.57, 0.52, 0.90)
            line(0.60, 0.52, 0.76, 0.66)                        // leva verso il basso
            circle(0.80, 0.70, 0.09, filled: true, opacity: 0.9) // rullo dietro
            var arc = Path()
            arc.addArc(center: point(0.60, 0.52), radius: frame.width * 0.26,
                       startAngle: .degrees(10), endAngle: .degrees(46), clockwise: false)
            stroke(arc, opacity: 0.4, dash: [line, line * 1.4])

        case .abductor:
            // Di fronte: seduta al centro e i due cuscinetti che si aprono.
            floor()
            bar(0.34, 0.34, 0.32, 0.12, radius: 0.05)           // seduta larga, di fronte
            line(0.50, 0.34, 0.50, 0.14)                        // schienale
            line(0.50, 0.46, 0.50, 0.88)                        // colonna centrale
            bar(0.14, 0.56, 0.14, 0.26, radius: 0.06)           // cuscinetto sinistro
            bar(0.72, 0.56, 0.14, 0.26, radius: 0.06)           // cuscinetto destro
            line(0.34, 0.52, 0.28, 0.62)                        // bracci verso i cuscinetti
            line(0.66, 0.52, 0.72, 0.62)

        case .glute:
            floor()
            line(0.16, 0.14, 0.16, 0.90)                        // montante
            bar(0.16, 0.26, 0.26, 0.09, radius: 0.04)           // appoggio busto
            bar(0.16, 0.44, 0.16, 0.07, radius: 0.03, opacity: 0.8) // maniglie
            line(0.30, 0.62, 0.66, 0.70)                        // leva indietro
            circle(0.74, 0.72, 0.10, filled: true, opacity: 0.9) // rullo
            var arc = Path()
            arc.addArc(center: point(0.30, 0.62), radius: frame.width * 0.44,
                       startAngle: .degrees(12), endAngle: .degrees(-18), clockwise: true)
            stroke(arc, opacity: 0.4, dash: [line, line * 1.4])

        case .hipThrust:
            floor()
            bar(0.12, 0.52, 0.34, 0.09, radius: 0.03)           // schienale
            bar(0.46, 0.66, 0.34, 0.10, radius: 0.04)           // pad anche
            line(0.16, 0.61, 0.16, 0.90)
            line(0.78, 0.76, 0.78, 0.90)
            circle(0.86, 0.80, 0.10)                            // disco

        case .calf:
            // Il gradino con le spalliere: è quello che si riconosce.
            floor()
            bar(0.14, 0.74, 0.46, 0.10, radius: 0.04)           // pedana rialzata
            line(0.24, 0.74, 0.24, 0.40)                        // busto
            line(0.24, 0.40, 0.44, 0.40)                        // spalliere
            bar(0.40, 0.34, 0.10, 0.12, radius: 0.04)
            var arc = Path()                                     // il tallone che sale
            arc.addArc(center: point(0.60, 0.84), radius: frame.width * 0.16,
                       startAngle: .degrees(-90), endAngle: .degrees(-20), clockwise: false)
            stroke(arc, opacity: 0.5, dash: [line, line * 1.3])
            hollow(0.72, 0.30, 0.14, 0.50, radius: 0.05, opacity: 0.6)  // pacco pesi

        case .chestPress:
            floor()
            hollow(0.08, 0.30, 0.15, 0.50, radius: 0.05, opacity: 0.65)  // pacco pesi
            bar(0.30, 0.58, 0.30, 0.09, radius: 0.04)           // seduta
            bar(0.30, 0.30, 0.08, 0.28, radius: 0.03)           // schienale verticale
            line(0.38, 0.67, 0.38, 0.90)
            line(0.56, 0.67, 0.56, 0.90)
            line(0.44, 0.42, 0.84, 0.42)                        // maniglie in avanti
            line(0.84, 0.34, 0.84, 0.50)

        case .shoulderPress:
            floor()
            hollow(0.08, 0.34, 0.15, 0.46, radius: 0.05, opacity: 0.65)
            bar(0.30, 0.62, 0.30, 0.09, radius: 0.04)           // seduta
            bar(0.30, 0.34, 0.08, 0.28, radius: 0.03)           // schienale
            line(0.38, 0.71, 0.38, 0.90)
            line(0.56, 0.71, 0.56, 0.90)
            line(0.46, 0.34, 0.46, 0.14)                        // montanti in alto
            line(0.72, 0.34, 0.72, 0.14)
            line(0.42, 0.14, 0.76, 0.14)                        // maniglie sopra la testa

        case .pecFly:
            // Di fronte: i due bracci che si chiudono davanti al petto.
            floor()
            // Le due ali che si chiudono davanti al petto: braccia orizzontali.
            bar(0.42, 0.52, 0.16, 0.12, radius: 0.05)           // schienale visto di fronte
            line(0.50, 0.90, 0.50, 0.64)                        // colonna
            line(0.42, 0.40, 0.16, 0.40)                        // braccio sinistro disteso
            line(0.58, 0.40, 0.84, 0.40)                        // braccio destro disteso
            bar(0.08, 0.30, 0.10, 0.22, radius: 0.05)           // impugnature verticali
            bar(0.82, 0.30, 0.10, 0.22, radius: 0.05)
            line(0.42, 0.40, 0.42, 0.52)
            line(0.58, 0.40, 0.58, 0.52)

        case .lateralRaise:
            // Di fronte: le due leve che salgono ai lati, come le braccia.
            floor()
            // Le leve che salgono verso l'alto, come le braccia nelle alzate.
            bar(0.42, 0.60, 0.16, 0.12, radius: 0.05)           // seduta
            line(0.50, 0.90, 0.50, 0.72)
            line(0.42, 0.58, 0.22, 0.28)                        // leva sinistra verso l'alto
            line(0.58, 0.58, 0.78, 0.28)                        // leva destra
            bar(0.14, 0.16, 0.16, 0.12, radius: 0.05)           // cuscinetti in alto
            bar(0.70, 0.16, 0.16, 0.12, radius: 0.05)

        case .latPulldown:
            floor()
            line(0.24, 0.10, 0.24, 0.90)                        // colonna
            line(0.24, 0.12, 0.72, 0.12)                        // braccio alto
            line(0.72, 0.12, 0.72, 0.30)                        // cavo
            line(0.60, 0.30, 0.84, 0.30)                        // barra
            bar(0.56, 0.62, 0.28, 0.09, radius: 0.03)           // seduta
            bar(0.58, 0.48, 0.22, 0.07, radius: 0.03, opacity: 0.75) // pad ginocchia
            hollow(0.18, 0.34, 0.13, 0.44, radius: 0.05, opacity: 0.6)

        case .seatedRow:
            floor()
            hollow(0.08, 0.30, 0.15, 0.50, radius: 0.05, opacity: 0.65)  // pacco pesi
            line(0.23, 0.44, 0.62, 0.56)                        // cavo che tira
            line(0.62, 0.48, 0.62, 0.64)                        // maniglia
            bar(0.68, 0.62, 0.26, 0.09, radius: 0.04)           // seduta
            bar(0.86, 0.36, 0.08, 0.26, radius: 0.03)           // schienale/petto
            line(0.72, 0.71, 0.72, 0.90)
            line(0.90, 0.71, 0.90, 0.90)

        case .pullover:
            floor()
            bar(0.30, 0.60, 0.30, 0.09, radius: 0.04)           // seduta
            bar(0.30, 0.34, 0.08, 0.26, radius: 0.03)           // schienale
            line(0.38, 0.69, 0.38, 0.90)
            line(0.56, 0.69, 0.56, 0.90)
            line(0.40, 0.30, 0.72, 0.24)                        // braccio rotante
            circle(0.78, 0.24, 0.07, filled: true, opacity: 0.9)
            var arc = Path()
            arc.addArc(center: point(0.40, 0.30), radius: frame.width * 0.38,
                       startAngle: .degrees(-10), endAngle: .degrees(30), clockwise: false)
            stroke(arc, opacity: 0.4, dash: [line, line * 1.4])

        case .cableColumn:
            floor()
            line(0.30, 0.08, 0.30, 0.90)                        // montante
            line(0.70, 0.08, 0.70, 0.90)
            line(0.30, 0.10, 0.70, 0.10)                        // traversa
            circle(0.50, 0.22, 0.07)                            // carrucola
            line(0.50, 0.29, 0.50, 0.58)                        // cavo
            line(0.42, 0.58, 0.58, 0.58)                        // maniglia
            hollow(0.24, 0.30, 0.12, 0.48, radius: 0.05, opacity: 0.55)

        case .smithMachine:
            floor()
            line(0.22, 0.08, 0.22, 0.90)
            line(0.78, 0.08, 0.78, 0.90)
            line(0.22, 0.10, 0.78, 0.10)
            line(0.16, 0.46, 0.84, 0.46)                        // bilanciere
            circle(0.16, 0.46, 0.07)
            circle(0.84, 0.46, 0.07)

        case .dipAssist:
            floor()
            line(0.26, 0.10, 0.26, 0.90)
            line(0.74, 0.10, 0.74, 0.90)
            line(0.26, 0.12, 0.74, 0.12)
            line(0.34, 0.42, 0.48, 0.42)                        // maniglie dip
            line(0.52, 0.42, 0.66, 0.42)
            bar(0.38, 0.66, 0.24, 0.08, radius: 0.03)           // pedana assistita

        case .abCrunch:
            floor()
            bar(0.34, 0.62, 0.28, 0.09, radius: 0.03)
            line(0.36, 0.62, 0.36, 0.30)
            line(0.36, 0.32, 0.62, 0.26)                        // pad spalle
            circle(0.66, 0.24, 0.06, filled: true, opacity: 0.85)
            line(0.40, 0.71, 0.40, 0.90)
            hollow(0.12, 0.40, 0.13, 0.40, radius: 0.05, opacity: 0.6)

        case .backExtension:
            floor()
            line(0.16, 0.72, 0.62, 0.34)                        // piano inclinato
            bar(0.52, 0.26, 0.22, 0.08, radius: 0.03)
            circle(0.22, 0.78, 0.07)                            // rulli piedi
            circle(0.36, 0.78, 0.07)
            line(0.30, 0.60, 0.30, 0.86)

        case .bench:
            floor()
            bar(0.14, 0.52, 0.56, 0.09, radius: 0.03)           // seduta
            line(0.22, 0.61, 0.22, 0.90)
            line(0.62, 0.61, 0.62, 0.90)
            line(0.70, 0.52, 0.88, 0.36)                        // schienale inclinato

        case .benchRack:
            floor()
            bar(0.14, 0.58, 0.52, 0.08, radius: 0.03)
            line(0.22, 0.66, 0.22, 0.90)
            line(0.58, 0.66, 0.58, 0.90)
            line(0.30, 0.22, 0.30, 0.58)                        // colonnine
            line(0.70, 0.22, 0.70, 0.58)
            line(0.20, 0.28, 0.80, 0.28)                        // bilanciere
            circle(0.20, 0.28, 0.06)
            circle(0.80, 0.28, 0.06)

        case .dumbbellRack:
            floor()
            line(0.10, 0.86, 0.90, 0.86)
            line(0.14, 0.86, 0.20, 0.56)
            line(0.86, 0.86, 0.80, 0.56)
            line(0.20, 0.56, 0.80, 0.56)                        // ripiano alto
            line(0.16, 0.72, 0.84, 0.72)                        // ripiano basso
            for x in [CGFloat(0.30), 0.50, 0.70] {
                circle(x, 0.50, 0.05, filled: true, opacity: 0.85)
                circle(x, 0.66, 0.05, filled: true, opacity: 0.7)
            }

        case .plateRack:
            floor()
            line(0.50, 0.24, 0.50, 0.90)                        // palo
            circle(0.32, 0.62, 0.16)
            circle(0.68, 0.62, 0.16)
            circle(0.32, 0.62, 0.04, filled: true)
            circle(0.68, 0.62, 0.04, filled: true)

        case .kettlebell:
            floor()
            circle(0.50, 0.66, 0.22, filled: true, opacity: 0.9)
            var handle = Path()
            handle.addArc(center: point(0.50, 0.38), radius: frame.width * 0.14,
                          startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            stroke(handle)

        case .platform:
            floor()
            bar(0.14, 0.66, 0.72, 0.12, radius: 0.05)
            line(0.24, 0.78, 0.24, 0.88)
            line(0.76, 0.78, 0.76, 0.88)
            line(0.34, 0.56, 0.42, 0.56, opacity: 0.7)
            line(0.58, 0.56, 0.66, 0.56, opacity: 0.7)

        case .mat:
            floor()
            bar(0.10, 0.70, 0.62, 0.10, radius: 0.04, opacity: 0.85)
            var roll = Path()
            roll.addArc(center: point(0.78, 0.75), radius: frame.width * 0.12,
                        startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            stroke(roll)
            circle(0.78, 0.75, 0.04)

        case .stretchArea:
            hollow(0.12, 0.34, 0.76, 0.48, radius: 0.06, opacity: 0.55)
            var dashes = Path()
            dashes.move(to: point(0.12, 0.58))
            dashes.addLine(to: point(0.88, 0.58))
            stroke(dashes, opacity: 0.45, dash: [line * 1.6, line * 1.6])
            circle(0.34, 0.46, 0.06)
            circle(0.66, 0.70, 0.06)

        case .unknown:
            hollow(0.16, 0.24, 0.68, 0.62, radius: 0.08, opacity: 0.5)
            var mark = Path()
            mark.addArc(center: point(0.50, 0.46), radius: frame.width * 0.10,
                        startAngle: .degrees(160), endAngle: .degrees(20), clockwise: false)
            mark.addLine(to: point(0.50, 0.62))
            stroke(mark)
            circle(0.50, 0.72, 0.022, filled: true)
        }
    }
}
