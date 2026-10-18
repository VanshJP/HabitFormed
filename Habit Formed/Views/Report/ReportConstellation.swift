import SwiftUI

/// The report's Constellation layout: the day as a night sky. Each habit is
/// a star, lit in its colour once done and sized by its run; lit stars are
/// joined in the order they were logged, and dashed lines carry the figure on
/// through the stars still dark. Stars wind through the sky three to a row,
/// so each join is short, each named under it in its column. The Apple
/// Health numbers follow as sky notes. It is the whole image, night whatever
/// the card's background. Painted fills only, so `ImageRenderer` draws it.
struct ReportConstellation: View {
    let report: DailyReport
    let options: ReportOptions

    private let width: CGFloat = 342
    private let cellHeight: CGFloat = 88
    /// The first row's stars sit this far down, so the largest clears the top.
    private let topInset: CGFloat = 24
    /// A column's width less a gap, so names side by side never touch.
    private var labelWidth: CGFloat { width / 3 - 10 }
    private var soft: Color { AppColors.starlight.opacity(0.68) }

    var body: some View {
        let stars = ordered
        let points = stars.indices.map { position($0, of: stars.count) }
        let lit = stars.filter(\.isDone).count
        let skyHeight = CGFloat(max((stars.count + 2) / 3, 1)) * cellHeight
        let lines = report.health.lines(showing: options.metrics)
        let note = options.trimmedNote

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
                        .position(x: labelX(index, of: stars.count), y: points[index].y + starSize(stars[index]) / 2 + 20)
                }
            }
            .frame(width: width, height: skyHeight)

            if report.items.count > stars.count {
                Text("+\(report.items.count - stars.count) more past the horizon")
                    .font(.custom("Baskerville-Italic", size: 14))
                    .foregroundStyle(soft)
            }
            if !note.isEmpty {
                Text(note)
                    .font(.custom("Baskerville-Italic", size: 15))
                    .foregroundStyle(AppColors.starlight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !lines.isEmpty { skyNotes(lines) }
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
    /// One or two stars share the sky's width instead of hugging its left.
    private func position(_ index: Int, of count: Int) -> CGPoint {
        let dx: [CGFloat] = [-12, 8, -4, 12, -8, 6, 10, -12, 3, -6, 11, -2]
        let dy: [CGFloat] = [-6, 5, -2, 3, -5, 4, 2, -3, 6, -4, 0, 4]
        return CGPoint(
            x: labelX(index, of: count) + dx[index % dx.count],
            y: CGFloat(index / 3) * cellHeight + topInset + dy[index % dy.count]
        )
    }

    /// The middle of a star's column, where its name sits.
    private func labelX(_ index: Int, of count: Int) -> CGFloat {
        if count < 3 { return width * CGFloat(index + 1) / CGFloat(count + 1) }
        let row = index / 3
        let column = row.isMultiple(of: 2) ? index % 3 : 2 - index % 3
        return CGFloat(column) * width / 3 + width / 6
    }

    /// A lit star's width, larger the longer its run while streaks show; a
    /// dark one's small ring.
    private func starSize(_ item: DailyReport.Item) -> CGFloat {
        let run = CGFloat(min(item.streak, 6))
        if item.isDone { return options.showStreaks ? 16 + run * 3 : 22 }
        return 6 + (options.showStreaks ? min(run, 4) * 1.5 : 0)
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
        let size = starSize(item)
        if item.isDone {
            ZStack {
                Sparkle()
                    .fill(Color(hex: item.colorHex).glyphTone)
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color.white)
                    .frame(width: 3.5, height: 3.5)
            }
        } else {
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
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(soft)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(report.expected == 0 ? "\(report.done)" : "\(report.done) of \(report.expected)")
                    .font(.custom("Baskerville-SemiBold", size: 28))
                Text("Stars lit")
                    .font(.system(size: 11, design: .monospaced))
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

    /// The Health numbers two to a line, so each keeps its full size.
    private func skyNotes(_ lines: [HealthLine]) -> some View {
        let rows = stride(from: 0, to: lines.count, by: 2).map { Array(lines[$0..<min($0 + 2, lines.count)]) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    ForEach(rows[index], id: \.self) { line in
                        Text("\(line.label.uppercased()) \(line.value)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if rows[index].count < 2 {
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
