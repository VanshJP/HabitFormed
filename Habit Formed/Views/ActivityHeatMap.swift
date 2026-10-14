import SwiftUI

/// Contributions-style heat map: columns are weeks (oldest left), rows are
/// days of the week. Logged days take the habit's colour; future days in the
/// current week are blank so the grid stays rectangular.
///
/// With `onToggleDay` set, every past cell is a button that adds or removes
/// that day's log, which is how the habit's page fixes history.
struct ActivityHeatMap: View {
    let completionDates: [Date]
    let accent: Color
    var weeks: Int = 5
    var cellSpacing: CGFloat = 3
    var cornerRadius: CGFloat = 3
    /// When nil, cells stretch to fill the width; when set, cells render at
    /// exactly this size.
    var cellSize: CGFloat? = nil
    var onToggleDay: ((Date) -> Void)? = nil

    var body: some View {
        let grid = Self.buildGrid(weeks: weeks)
        let completed = Set(completionDates.map { $0.startOfDay })

        Group {
            if let cellSize {
                gridView(grid: grid, completed: completed, cellSize: cellSize)
            } else {
                GeometryReader { proxy in
                    let cs = max(2, (proxy.size.width - cellSpacing * CGFloat(weeks - 1)) / CGFloat(weeks))
                    gridView(grid: grid, completed: completed, cellSize: cs)
                }
                .aspectRatio(CGFloat(weeks) / 7.0, contentMode: .fit)
            }
        }
    }

    private func gridView(grid: [[Date?]], completed: Set<Date>, cellSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(0..<grid.count, id: \.self) { col in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { row in
                        cell(date: grid[col][row], completed: completed, size: cellSize)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(date: Date?, completed: Set<Date>, size: CGFloat) -> some View {
        if let date {
            let isCompleted = completed.contains(date)
            let face = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isCompleted ? accent.glyphTone : Color.white.opacity(0.08))
                .overlay {
                    if date.isToday {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                    }
                }
                .frame(width: size, height: size)

            if let onToggleDay {
                Button {
                    onToggleDay(date)
                } label: {
                    face.contentShape(.rect)
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityValue(isCompleted ? "Logged" : "Not logged")
                .accessibilityHint(isCompleted ? "Removes this day's log" : "Logs this day")
            } else {
                face
            }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    /// `grid[column][row]`: column 0 is the oldest week, column `weeks - 1`
    /// the current one. Days after today are nil.
    static func buildGrid(weeks: Int) -> [[Date?]] {
        let cal = Calendar.current
        let today = Date().startOfDay
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }
        return (0..<weeks).map { weekOffset in
            let offset = weekOffset - (weeks - 1)
            let weekStart = cal.date(byAdding: .weekOfYear, value: offset, to: thisWeekStart) ?? thisWeekStart
            return (0..<7).map { dayOffset in
                let date = cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                return date > today ? nil : date.startOfDay
            }
        }
    }
}
