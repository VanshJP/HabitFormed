import SwiftUI

/// GitHub-contributions-style heatmap. Columns are weeks (oldest left → newest
/// right), rows are days of the week. Cells are filled with the habit's accent
/// color on completed days and dimmed otherwise. Future days in the current
/// week render as a fully transparent placeholder so the grid stays rectangular.
struct ActivityHeatMap: View {
    let completionDates: [Date]
    let accent: Color
    var weeks: Int = 5
    var cellSpacing: CGFloat = 3
    var cornerRadius: CGFloat = 3
    /// When nil, cells stretch to fill the container's width using a fixed
    /// `weeks × 7` aspect ratio. When set, cells render at that exact size.
    var cellSize: CGFloat? = nil

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
            let isToday = date.isToday
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isCompleted ? accent : Color.white.opacity(0.08))
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    }
                }
                .frame(width: size, height: size)
        } else {
            // Future day in the current week: keep the grid rectangular.
            Color.clear.frame(width: size, height: size)
        }
    }

    /// 2-D matrix of dates: `grid[column][row]` where column 0 is the oldest
    /// week and column `weeks-1` is the current week. Days beyond today are
    /// nil so the consumer can render them as placeholders.
    private static func buildGrid(weeks: Int) -> [[Date?]] {
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
