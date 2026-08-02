import SwiftUI

/// Calendario mensile con i pallini colorati degli allenamenti svolti.
struct CalendarView: View {
    @Binding var month: Date
    var selected: String?
    var onSelect: ((String) -> Void)?
    /// [iso: colori delle schede allenate quel giorno]
    var marks: [String: [String]] = [:]

    private var weeks: [[Date]] { DateKey.monthMatrix(month) }
    private var monthIndex: Int { DateKey.calendar.component(.month, from: month) }

    var body: some View {
        Panel(padding: 14, radius: Theme.rLg) {
            VStack(spacing: 10) {
                HStack {
                    navButton("chevron.left") { month = DateKey.addingMonths(-1, to: month) }
                    Spacer()
                    Text("\(Fmt.monthsIT[monthIndex - 1].capitalized) \(DateKey.calendar.component(.year, from: month))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    navButton("chevron.right") { month = DateKey.addingMonths(1, to: month) }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(Fmt.dowIT, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                    }
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        ForEach(week, id: \.self) { date in
                            dayCell(date)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let iso = DateKey.iso(date)
        let dots = marks[iso] ?? []
        let isOut = DateKey.calendar.component(.month, from: date) != monthIndex
        let isToday = DateKey.sameDay(date, Date())
        let isSelected = selected == iso

        return Button {
            onSelect?(iso)
        } label: {
            VStack(spacing: 2) {
                Text("\(DateKey.calendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color(hex: "#0a0f1a")
                                     : (isOut ? Theme.textFaint.opacity(0.45) : Theme.text))
                HStack(spacing: 2) {
                    ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, hex in
                        Circle().fill(Color(hex: hex)).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isSelected ? Theme.defaultAccent : (isToday ? Theme.surfaceHi : .clear),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isToday && !isSelected ? Theme.borderHi : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textDim)
                .frame(width: 30, height: 30)
                .background(Theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
