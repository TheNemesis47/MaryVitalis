import SwiftUI

/// Il design system della SPA (style.css) portato su SwiftUI.
enum Theme {
    static let bg = Color(hex: "#080d18")
    static let bgSoft = Color(hex: "#0d1424")
    static let surface = Color(hex: "#94a3b8").opacity(0.06)
    static let surfaceHi = Color(hex: "#94a3b8").opacity(0.11)
    static let border = Color(hex: "#94a3b8").opacity(0.14)
    static let borderHi = Color(hex: "#94a3b8").opacity(0.26)

    static let text = Color(hex: "#e9eff8")
    static let textDim = Color(hex: "#96a6bf")
    static let textFaint = Color(hex: "#64748b")

    static let defaultAccent = Color(hex: "#38bdf8")

    static let rSm: CGFloat = 10
    static let rMd: CGFloat = 14
    static let rLg: CGFloat = 20
    static let rXl: CGFloat = 26

    /// L'aura di fondo di `body::before`.
    static var background: some View {
        ZStack {
            LinearGradient(colors: [bgSoft, bg], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: "#38bdf8").opacity(0.16), .clear],
                           center: UnitPoint(x: 0.12, y: -0.08), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(hex: "#a78bfa").opacity(0.13), .clear],
                           center: UnitPoint(x: 0.92, y: 0.04), startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Color(hex: "#fb7185").opacity(0.08), .clear],
                           center: UnitPoint(x: 0.6, y: 1.0), startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        default:
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Mattoni riutilizzabili

/// La "card" scura con bordo sottile usata ovunque nella SPA.
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = Theme.rLg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

/// Pillola con testo secondario (`.meta-pill`).
struct MetaPill: View {
    let text: String
    var color: Color = Theme.textDim

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(color == Theme.textDim ? Theme.border : color.opacity(0.35), lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.text)
            Spacer()
            if let trailing {
                Button(trailing) { action?() }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.defaultAccent)
            }
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11.5, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textFaint)
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bottone pieno con l'accento corrente.
struct PrimaryButtonStyle: ButtonStyle {
    var accent: Color = Theme.defaultAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(hex: "#0a0f1a"))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Bottone trasparente con bordo (`.btn-ghost`).
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Chip selezionabile dei giorni / delle durate di recupero.
struct Chip: View {
    let label: String
    var active = false
    var done = false
    var accent: Color = Theme.defaultAccent

    var body: some View {
        Text(label)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(active ? Color(hex: "#0a0f1a") : (done ? accent : Theme.textDim))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? accent : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(active ? .clear : (done ? accent.opacity(0.5) : Theme.border), lineWidth: 1))
    }
}

struct ProgressTrack: View {
    let percent: Int
    var accent: Color = Theme.defaultAccent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHi)
                Capsule()
                    .fill(accent)
                    .frame(width: geo.size.width * CGFloat(percent) / 100)
            }
        }
        .frame(height: 8)
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        Panel(padding: 14, radius: Theme.rMd) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }
}

struct RecapLine: View {
    let left: String
    let right: String
    var leftColor: Color = Theme.textDim

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left)
                .font(.system(size: 14))
                .foregroundStyle(leftColor)
            Spacer(minLength: 12)
            Text(right)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(icon).font(.system(size: 42))
            Text(title).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Griglia fluida a colonne adattive, come le `*-grid` del CSS.
struct FlowGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var minWidth: CGFloat = 160
    var spacing: CGFloat = 12
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: spacing)], spacing: spacing) {
            ForEach(items) { content($0) }
        }
    }
}
