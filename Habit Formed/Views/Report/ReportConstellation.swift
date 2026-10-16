import SwiftUI

/// The report's Constellation layout: the day as a night sky. Each habit is
/// a star, lit in its colour once done and sized by its run; lit stars are
/// joined in the order they were logged, and dashed lines carry the figure on
/// through the stars still dark. Stars wind through the sky three to a row,
/// so each join is short. The Apple Health numbers follow as sky notes. It is
/// the whole image, night whatever the card's background. Painted fills
/// only, so `ImageRenderer` draws it.
struct ReportConstellation: View {
    let report: DailyReport
    let options: ReportOptions

    private let width: CGFloat = 342
    private let cellHeight: CGFloat = 86
    private let labelWidth: CGFloat = 108
    private var soft: Color { AppColors.starlight.opacity(0.68) }

    var body: some View {
        let stars = ordered
        let points = stars.indices.map { position($0) }
        let lit = stars.filter(\.isDone).count
        let skyHeight = CGFloat(max((stars.count + 2) / 3, 1)) * cellHeight + 8
        let lines = report.health.lines(showing: options.metrics)
        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 16) {
            header
            ZStack(alignment: .topLeading) {
                ForEach(Array(specks(height: skyHeight).enumerated()), id: \.offset) { _, speck in
                    Circle()
                        .fill(AppColors.starlight.opacity(speck.opacity))
                        .frame(width: speck.size, height: speck.size)
                        .position(speck.point)
                }
                joins(points, lit: lit)
                ForEach(stars.indices, id: \.self) { index in
                    star(stars[index]).position(points[index])
                }
                ForEach(stars.indices, id: \.self) { index in
                    label(stars[index])
                        .position(x: min(max(points[index].x, labelWidth / 2), width - labelWidth / 2), y: points[index].y + 28)
                }
            }
            .frame(width: width, height: skyHeight)

            if report.items.count > stars.count {
                Text("+\(report.items.count - stars.count) more past the horizon")
                    .font(.custom("Baskerville-Italic", size: 13))
                    .foregroundStyle(soft)
            }
            if !stars.isEmpty {
                Text(lit == 0 ? "Dashed lines join the stars still to light" : "Lit stars are done, joined in the order you logged them. Dashed lines finish the figure")
                    .font(.custom("Baskerville", size: 14))
                    .foregroundStyle(soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !note.isEmpty {
                Text(note)
                    .font(.custom("Baskerville-Italic", size: 15))
                    .foregroundStyle(AppColors.starlight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !lines.isEmpty { skyNotes(lines) }
            Text("Habit Formed")
                .font(.custom("Baskerville", size: 13))
                .foregroundStyle(soft)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: ReportCardView.width, alignment: .leading)
        .background(AppColors.nightSky)
    }

    // MARK: - Sky

    /// Done stars by the time they were logged, then the rest as listed.
    private var ordered: [DailyReport.Item] {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let done = shown.filter(\.isDone).sorted { ($0.loggedAt ?? .distantFuture) < ($1.loggedAt ?? .distantFuture) }
        return done + shown.filter { !$0.isDone }
    }

    /// Three to a row, the rows winding back and forth so the next star is
    /// always beside the last, each nudged off the grid so the sky is not one.
    private func position(_ index: Int) -> CGPoint {
        let row = index / 3
        let column = row.isMultiple(of: 2) ? index % 3 : 2 - index % 3
        let dx: [CGFloat] = [-16, 12, -6, 18, -12, 8, 14, -18, 4, -8, 16, -2]
        let dy: [CGFloat] = [-6, 8, -2, 4, -8, 6, 2, -4, 8, -6, 0, 6]
        return CGPoint(
            x: CGFloat(column) * width / 3 + width / 6 + dx[index % dx.count],
            y: CGFloat(row) * cellHeight + 22 + dy[index % dy.count]
        )
    }

    /// Solid between lit stars in the order logged; dashed on from the last
    /// lit one through the dark.
    private func joins(_ points: [CGPoint], lit: Int) -> some View {
        ZStack {
            Path { path in
                guard lit > 1 else { return }
                path.addLines(Array(points.prefix(lit)))
            }
            .stroke(AppColors.starlight.opacity(0.5), lineWidth: 1)
            Path { path in
                let rest = Array(points.suffix(from: max(lit - 1, 0)))
                guard rest.count > 1 else { return }
                path.addLines(rest)
            }
            .stroke(AppColors.starlight.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
    }

    @ViewBuilder
    private func star(_ item: DailyReport.Item) -> some View {
        let run = CGFloat(min(item.streak, 6))
        if item.isDone {
            let tint = Color(hex: item.colorHex).glyphTone
            let size = options.showStreaks ? 18 + run * 4 : 24
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.35), lineWidth: 1)
                    .frame(width: size + 12, height: size + 12)
                Sparkle()
                    .fill(tint)
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color.white)
                    .frame(width: 3.5, height: 3.5)
            }
        } else {
            let size = 6 + (options.showStreaks ? min(run, 4) * 1.5 : 0)
            Circle()
                .strokeBorder(AppColors.starlight.opacity(0.55), lineWidth: 1.2)
                .frame(width: size, height: size)
        }
    }

    /// The name, and when it was logged or how close it came, on a patch of
    /// sky so the joins pass behind it.
    private func label(_ item: DailyReport.Item) -> some View {
        VStack(spacing: 1) {
            Text(item.title)
                .font(.custom("Baskerville-SemiBoldItalic", size: 14))
                .foregroundStyle(item.isDone ? AppColors.starlight : soft)
            if let meta = meta(item) {
                Text(meta)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(soft)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 3)
        .background(AppColors.nightSky)
        .frame(width: labelWidth)
    }

    private func meta(_ item: DailyReport.Item) -> String? {
        let run = options.showStreaks && item.streak > 0 ? "\(item.streak) \(item.streakUnit)" : nil
        if item.isDone {
            let time = item.loggedAt.map { $0.formatted(date: .omitted, time: .shortened) }
            return [time, run].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        }
        if let detail = item.detail { return detail }
        if let run { return "\(run) at stake" }
        return item.status == .open ? "not yet" : nil
    }

    /// A few faint specks of dust, the same for the same day.
    private func specks(height: CGFloat) -> [(point: CGPoint, size: CGFloat, opacity: Double)] {
        var state = UInt64(max(report.date.timeIntervalSince1970, 0)) | 1
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53)
        }
        return (0..<18).map { _ in
            let point = CGPoint(x: CGFloat(next()) * width, y: CGFloat(next()) * height)
            return (point: point, size: CGFloat(1 + next() * 1.4), opacity: 0.25 + next() * 0.3)
        }
    }

    // MARK: - Around the sky

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("The \(report.date.formatted(.dateTime.weekday(.wide))) sky")
                    .font(.custom("Baskerville-SemiBoldItalic", size: 30))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(soft)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(report.done) of \(report.expected)")
                    .font(.custom("Baskerville-SemiBold", size: 28))
                Text("Stars lit")
                    .font(.system(size: 10, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundStyle(soft)
            }
        }
        .foregroundStyle(AppColors.starlight)
    }

    private var subtitle: String {
        let date = report.date.formatted(.dateTime.month(.wide).day())
        return (report.name.isEmpty ? date : "\(report.name) · \(date)").uppercased()
    }

    private func skyNotes(_ lines: [HealthLine]) -> some View {
        let rows = stride(from: 0, to: lines.count, by: 3).map { Array(lines[$0..<min($0 + 3, lines.count)]) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(rows[index], id: \.self) { line in
                        Text("\(line.label.uppercased()) \(line.value)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(0..<(3 - rows[index].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(AppColors.starlight.opacity(0.85))
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(AppColors.starlight.opacity(0.15)).frame(height: 1) }
    }
}

/// A four-point star: curves pulled in to the centre between its points.
private struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: centre)
        path.closeSubpath()
        return path
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
