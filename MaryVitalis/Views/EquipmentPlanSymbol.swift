import SwiftUI

/// Sagoma vettoriale di un attrezzo visto dall'alto.
///
/// Non usa fotografie o asset raster: le forme restano nitide a qualsiasi
/// dimensione e possono assumere il colore dell'allenamento in corso.
struct EquipmentPlanSymbol: View {
    let machine: GymMachine
    var tint: Color = Theme.textDim

    private var style: Style {
        let id = machine.id.lowercased()
        let name = machine.name.lowercased()

        if id == "colonna-multi-4" { return .multiFour }
        if id == "colonna-multi-2" { return .multiTwo }
        if id.contains("adjustable-pulley") { return .cable }
        if id.contains("tapis") { return .treadmill }
        if id.contains("cyclette") { return .bike }
        if id.contains("ellittica") { return .elliptical }
        if id == "stepmill" { return .stepper }
        if id == "rematore" { return .rower }
        if id == "manubri" { return .dumbbellRack }
        if id == "panche" { return .benchGroup }
        if id.contains("panca") || id == "area-corpo-libero" { return .bench }
        if id == "pedana-vibrante" { return .platform }
        if name.contains("press") || name.contains("squat") { return .press }
        if name.contains("row") || name.contains("pulldown") || name.contains("lat ") { return .pull }
        return .selectorized
    }

    var body: some View {
        Group {
            // Un attrezzo inventato da chi mappa la sala non ha una sagoma
            // vista dall'alto: al posto di quella sbagliata, l'icona scelta.
            if let symbol = machine.symbolName {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                    let frame = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
                    draw(style, in: frame, context: &context)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private enum Style {
        case selectorized
        case press
        case pull
        case cable
        case multiTwo
        case multiFour
        case treadmill
        case bike
        case elliptical
        case stepper
        case rower
        case bench
        case benchGroup
        case dumbbellRack
        case platform
    }

    private func draw(_ style: Style, in frame: CGRect, context: inout GraphicsContext) {
        switch style {
        case .selectorized: drawSelectorized(in: frame, context: &context)
        case .press: drawPress(in: frame, context: &context)
        case .pull: drawPull(in: frame, context: &context)
        case .cable: drawCable(in: frame, context: &context)
        case .multiTwo: drawMultiStation(count: 2, in: frame, context: &context)
        case .multiFour: drawMultiStation(count: 4, in: frame, context: &context)
        case .treadmill: drawTreadmill(in: frame, context: &context)
        case .bike: drawBike(in: frame, context: &context)
        case .elliptical: drawElliptical(in: frame, context: &context)
        case .stepper: drawStepper(in: frame, context: &context)
        case .rower: drawRower(in: frame, context: &context)
        case .bench: drawBench(in: frame, context: &context)
        case .benchGroup: drawBenchGroup(in: frame, context: &context)
        case .dumbbellRack: drawDumbbellRack(in: frame, context: &context)
        case .platform: drawPlatform(in: frame, context: &context)
        }
    }

    // MARK: - Materiali

    private var frameColor: Color { Color(hex: "#c7d2e0").opacity(0.9) }
    private var frameShadow: Color { Color(hex: "#5b6b80").opacity(0.7) }
    private var padColor: Color { Color(hex: "#26354a") }
    private var padHighlight: Color { tint.opacity(0.88) }

    private func fill(_ rect: CGRect, radius: CGFloat, color: Color, context: inout GraphicsContext) {
        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
    }

    private func stroke(_ rect: CGRect, radius: CGFloat, color: Color, width: CGFloat = 1.5,
                        context: inout GraphicsContext) {
        context.stroke(Path(roundedRect: rect, cornerRadius: radius), with: .color(color), lineWidth: width)
    }

    private func circle(_ rect: CGRect, color: Color, context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func line(from start: CGPoint, to end: CGPoint, color: Color, width: CGFloat = 2,
                      context: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
                   in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + frame.width * x,
            y: frame.minY + frame.height * y,
            width: frame.width * width,
            height: frame.height * height
        )
    }

    private func p(_ x: CGFloat, _ y: CGFloat, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + frame.width * x, y: frame.minY + frame.height * y)
    }

    // MARK: - Isotoniche

    private func drawSelectorized(in frame: CGRect, context: inout GraphicsContext) {
        // Pacco pesi, telaio, seduta e rulli: la lettura resta chiara anche a 40 pt.
        fill(r(0.08, 0.12, 0.22, 0.76, in: frame), radius: 3, color: frameShadow, context: &context)
        for index in 0..<5 {
            let y = 0.2 + CGFloat(index) * 0.115
            line(from: p(0.11, y, in: frame), to: p(0.27, y, in: frame),
                 color: frameColor.opacity(0.65), width: 1, context: &context)
        }
        line(from: p(0.3, 0.2, in: frame), to: p(0.72, 0.2, in: frame),
             color: frameColor, width: 3, context: &context)
        line(from: p(0.3, 0.78, in: frame), to: p(0.72, 0.78, in: frame),
             color: frameColor, width: 3, context: &context)
        fill(r(0.48, 0.33, 0.27, 0.3, in: frame), radius: 5, color: padColor, context: &context)
        stroke(r(0.48, 0.33, 0.27, 0.3, in: frame), radius: 5,
               color: padHighlight, width: 1.5, context: &context)
        circle(r(0.76, 0.24, 0.16, 0.16, in: frame), color: padHighlight, context: &context)
        circle(r(0.76, 0.61, 0.16, 0.16, in: frame), color: padHighlight, context: &context)
    }

    private func drawPress(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.1, 0.2, 0.24, 0.6, in: frame), radius: 4, color: frameShadow, context: &context)
        fill(r(0.42, 0.34, 0.25, 0.32, in: frame), radius: 5, color: padColor, context: &context)
        stroke(r(0.42, 0.34, 0.25, 0.32, in: frame), radius: 5,
               color: padHighlight, width: 1.5, context: &context)
        line(from: p(0.64, 0.31, in: frame), to: p(0.88, 0.16, in: frame),
             color: frameColor, width: 3, context: &context)
        line(from: p(0.64, 0.69, in: frame), to: p(0.88, 0.84, in: frame),
             color: frameColor, width: 3, context: &context)
        fill(r(0.82, 0.08, 0.12, 0.23, in: frame), radius: 3, color: padHighlight, context: &context)
        fill(r(0.82, 0.69, 0.12, 0.23, in: frame), radius: 3, color: padHighlight, context: &context)
    }

    private func drawPull(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.08, 0.13, 0.2, 0.74, in: frame), radius: 3, color: frameShadow, context: &context)
        line(from: p(0.28, 0.2, in: frame), to: p(0.84, 0.2, in: frame),
             color: frameColor, width: 3, context: &context)
        line(from: p(0.28, 0.8, in: frame), to: p(0.84, 0.8, in: frame),
             color: frameColor, width: 3, context: &context)
        fill(r(0.48, 0.36, 0.26, 0.28, in: frame), radius: 5, color: padColor, context: &context)
        stroke(r(0.48, 0.36, 0.26, 0.28, in: frame), radius: 5,
               color: padHighlight, width: 1.5, context: &context)
        line(from: p(0.77, 0.2, in: frame), to: p(0.9, 0.34, in: frame),
             color: padHighlight, width: 2.5, context: &context)
        line(from: p(0.77, 0.8, in: frame), to: p(0.9, 0.66, in: frame),
             color: padHighlight, width: 2.5, context: &context)
    }

    // MARK: - Cavi

    private func drawCable(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.32, 0.08, 0.36, 0.84, in: frame), radius: 5, color: frameShadow, context: &context)
        stroke(r(0.38, 0.14, 0.24, 0.72, in: frame), radius: 3,
               color: frameColor, width: 1.5, context: &context)
        line(from: p(0.5, 0.18, in: frame), to: p(0.5, 0.82, in: frame),
             color: padHighlight, width: 2, context: &context)
        circle(r(0.43, 0.22, 0.14, 0.14, in: frame), color: padHighlight, context: &context)
        line(from: p(0.5, 0.28, in: frame), to: p(0.15, 0.2, in: frame),
             color: frameColor, width: 1.5, context: &context)
        line(from: p(0.5, 0.72, in: frame), to: p(0.85, 0.8, in: frame),
             color: frameColor, width: 1.5, context: &context)
        fill(r(0.05, 0.13, 0.2, 0.14, in: frame), radius: 3, color: padColor, context: &context)
        fill(r(0.75, 0.73, 0.2, 0.14, in: frame), radius: 3, color: padColor, context: &context)
    }

    private func drawMultiStation(count: Int, in frame: CGRect, context: inout GraphicsContext) {
        // La colonna portante è al centro; le postazioni sono realmente disposte attorno.
        let center = r(0.35, 0.34, 0.3, 0.32, in: frame)
        fill(center, radius: 6, color: frameShadow, context: &context)
        stroke(center, radius: 6, color: frameColor, width: 2, context: &context)
        circle(r(0.455, 0.455, 0.09, 0.09, in: frame), color: padHighlight, context: &context)

        let stations: [(CGRect, CGPoint)] = count == 4 ? [
            (r(0.35, 0.02, 0.3, 0.2, in: frame), p(0.5, 0.34, in: frame)),
            (r(0.35, 0.78, 0.3, 0.2, in: frame), p(0.5, 0.66, in: frame)),
            (r(0.02, 0.36, 0.2, 0.28, in: frame), p(0.35, 0.5, in: frame)),
            (r(0.78, 0.36, 0.2, 0.28, in: frame), p(0.65, 0.5, in: frame))
        ] : [
            (r(0.02, 0.36, 0.24, 0.28, in: frame), p(0.35, 0.5, in: frame)),
            (r(0.74, 0.36, 0.24, 0.28, in: frame), p(0.65, 0.5, in: frame))
        ]

        for (station, anchor) in stations {
            let stationCenter = CGPoint(x: station.midX, y: station.midY)
            line(from: anchor, to: stationCenter, color: frameColor, width: 1.5, context: &context)
            fill(station, radius: 4, color: padColor, context: &context)
            stroke(station, radius: 4, color: padHighlight, width: 1.4, context: &context)
        }
    }

    // MARK: - Cardio

    private func drawTreadmill(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.22, 0.06, 0.56, 0.88, in: frame), radius: 7, color: frameShadow, context: &context)
        fill(r(0.29, 0.2, 0.42, 0.65, in: frame), radius: 5, color: Color(hex: "#182334"), context: &context)
        for index in 0..<4 {
            let y = 0.3 + CGFloat(index) * 0.13
            line(from: p(0.32, y, in: frame), to: p(0.68, y, in: frame),
                 color: frameColor.opacity(0.32), width: 1, context: &context)
        }
        fill(r(0.18, 0.06, 0.64, 0.18, in: frame), radius: 4, color: padColor, context: &context)
        stroke(r(0.18, 0.06, 0.64, 0.18, in: frame), radius: 4,
               color: padHighlight, width: 1.5, context: &context)
    }

    private func drawBike(in frame: CGRect, context: inout GraphicsContext) {
        circle(r(0.35, 0.38, 0.3, 0.3, in: frame), color: frameShadow, context: &context)
        circle(r(0.41, 0.44, 0.18, 0.18, in: frame), color: Color(hex: "#172235"), context: &context)
        line(from: p(0.5, 0.43, in: frame), to: p(0.5, 0.16, in: frame),
             color: frameColor, width: 3, context: &context)
        line(from: p(0.5, 0.61, in: frame), to: p(0.5, 0.86, in: frame),
             color: frameColor, width: 3, context: &context)
        fill(r(0.31, 0.08, 0.38, 0.14, in: frame), radius: 4, color: padHighlight, context: &context)
        fill(r(0.34, 0.79, 0.32, 0.14, in: frame), radius: 4, color: padColor, context: &context)
        line(from: p(0.31, 0.51, in: frame), to: p(0.12, 0.51, in: frame),
             color: frameColor, width: 2, context: &context)
        line(from: p(0.69, 0.51, in: frame), to: p(0.88, 0.51, in: frame),
             color: frameColor, width: 2, context: &context)
    }

    private func drawElliptical(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.14, 0.12, 0.25, 0.74, in: frame), radius: 8, color: padColor, context: &context)
        fill(r(0.61, 0.12, 0.25, 0.74, in: frame), radius: 8, color: padColor, context: &context)
        stroke(r(0.14, 0.12, 0.25, 0.74, in: frame), radius: 8,
               color: padHighlight, width: 1.5, context: &context)
        stroke(r(0.61, 0.12, 0.25, 0.74, in: frame), radius: 8,
               color: padHighlight, width: 1.5, context: &context)
        line(from: p(0.27, 0.35, in: frame), to: p(0.5, 0.08, in: frame),
             color: frameColor, width: 2.5, context: &context)
        line(from: p(0.73, 0.65, in: frame), to: p(0.5, 0.92, in: frame),
             color: frameColor, width: 2.5, context: &context)
    }

    private func drawStepper(in frame: CGRect, context: inout GraphicsContext) {
        for index in 0..<5 {
            let inset = CGFloat(index) * 0.055
            fill(r(0.18 + inset, 0.12 + CGFloat(index) * 0.14, 0.64 - inset * 2, 0.12, in: frame),
                 radius: 2, color: index == 0 ? padHighlight : frameShadow, context: &context)
        }
        line(from: p(0.18, 0.12, in: frame), to: p(0.18, 0.88, in: frame),
             color: frameColor, width: 2, context: &context)
        line(from: p(0.82, 0.12, in: frame), to: p(0.82, 0.88, in: frame),
             color: frameColor, width: 2, context: &context)
    }

    private func drawRower(in frame: CGRect, context: inout GraphicsContext) {
        line(from: p(0.5, 0.12, in: frame), to: p(0.5, 0.9, in: frame),
             color: frameColor, width: 4, context: &context)
        circle(r(0.29, 0.04, 0.42, 0.42, in: frame), color: frameShadow, context: &context)
        circle(r(0.37, 0.12, 0.26, 0.26, in: frame), color: padHighlight, context: &context)
        fill(r(0.3, 0.58, 0.4, 0.22, in: frame), radius: 5, color: padColor, context: &context)
        stroke(r(0.3, 0.58, 0.4, 0.22, in: frame), radius: 5,
               color: frameColor, width: 1.5, context: &context)
    }

    // MARK: - Pesi liberi e altro

    private func drawBench(in frame: CGRect, context: inout GraphicsContext) {
        line(from: p(0.18, 0.18, in: frame), to: p(0.18, 0.86, in: frame),
             color: frameColor, width: 3, context: &context)
        line(from: p(0.82, 0.18, in: frame), to: p(0.82, 0.86, in: frame),
             color: frameColor, width: 3, context: &context)
        fill(r(0.3, 0.08, 0.4, 0.54, in: frame), radius: 6, color: padColor, context: &context)
        fill(r(0.3, 0.66, 0.4, 0.25, in: frame), radius: 5, color: padHighlight, context: &context)
        stroke(r(0.3, 0.08, 0.4, 0.83, in: frame), radius: 6,
               color: frameColor.opacity(0.7), width: 1.2, context: &context)
    }

    private func drawBenchGroup(in frame: CGRect, context: inout GraphicsContext) {
        for index in 0..<3 {
            let x = 0.08 + CGFloat(index) * 0.3
            fill(r(x, 0.12, 0.22, 0.76, in: frame), radius: 5,
                 color: index == 1 ? padHighlight : padColor, context: &context)
            stroke(r(x, 0.12, 0.22, 0.76, in: frame), radius: 5,
                   color: frameColor, width: 1.2, context: &context)
        }
    }

    private func drawDumbbellRack(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.1, 0.1, 0.8, 0.8, in: frame), radius: 5, color: frameShadow, context: &context)
        for row in 0..<3 {
            for column in 0..<3 {
                let x = 0.2 + CGFloat(column) * 0.23
                let y = 0.2 + CGFloat(row) * 0.27
                line(from: p(x, y + 0.04, in: frame), to: p(x + 0.13, y + 0.04, in: frame),
                     color: frameColor, width: 2.5, context: &context)
                circle(r(x - 0.025, y, 0.08, 0.08, in: frame), color: padHighlight, context: &context)
                circle(r(x + 0.105, y, 0.08, 0.08, in: frame), color: padHighlight, context: &context)
            }
        }
    }

    private func drawPlatform(in frame: CGRect, context: inout GraphicsContext) {
        fill(r(0.12, 0.12, 0.76, 0.76, in: frame), radius: 9, color: frameShadow, context: &context)
        stroke(r(0.19, 0.19, 0.62, 0.62, in: frame), radius: 7,
               color: padHighlight, width: 2, context: &context)
        for index in 0..<3 {
            let inset = 0.28 + CGFloat(index) * 0.08
            stroke(r(inset, inset, 1 - inset * 2, 1 - inset * 2, in: frame), radius: 4,
                   color: frameColor.opacity(0.65), width: 1, context: &context)
        }
    }
}
