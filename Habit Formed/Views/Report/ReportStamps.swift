import SwiftUI

/// The report's Stamps layout: an airmail envelope with a stamp per habit,
/// its glyph engraved in the habit's colour and its run as the value in the
/// corner. A stamp done today is postmarked with the day; one still open is
/// fresh and pale. The Apple Health numbers are the customs declaration. It
/// is the whole image, the envelope whatever the card's background. Painted
/// fills only, so `ImageRenderer` draws it.
struct ReportStamps: View {
    let report: DailyReport
    let options: ReportOptions

    private let stampSize = CGSize(width: 106, height: 132)
    private let gap: CGFloat = 12
    private let bodoni = "BodoniSvtyTwoITCTT-Book"
    private let bodoniItalic = "BodoniSvtyTwoITCTT-BookIta"
    private var soft: Color { AppColors.envelopeInk.opacity(0.72) }

    var body: some View {
        let shown = Array(report.items.prefix(ReportCardView.maxItems))
        let rows = stride(from: 0, to: shown.count, by: 3).map { Array(shown[$0..<min($0 + 3, shown.count)]) }
        let lines = report.health.lines(showing: options.metrics)
        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(spacing: 0) {
            stripes
            VStack(alignment: .leading, spacing: 18) {
                header
                VStack(spacing: gap) {
                    if shown.isEmpty {
                        Text("No habits on this card")
                            .font(.custom("Courier", size: 12))
                            .foregroundStyle(soft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(rows.indices, id: \.self) { index in
                        HStack(spacing: gap) {
                            ForEach(rows[index]) { stamp($0) }
                            ForEach(0..<(3 - rows[index].count), id: \.self) { _ in
                                Color.clear.frame(width: stampSize.width, height: 1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                if report.items.count > shown.count {
                    Text("+\(report.items.count - shown.count) more in the next envelope")
                        .font(.custom("Courier", size: 11))
                        .foregroundStyle(soft)
                }
                if !lines.isEmpty { customs(lines) }
                if !note.isEmpty {
                    Text("“\(note)”")
                        .font(.custom(bodoniItalic, size: 17))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(options.showStreaks ? "Postmarked = done today, the corner is the run" : "Postmarked = done today")
                    Spacer(minLength: 8)
                    Text("Habit Formed")
                }
                .font(.custom("Courier", size: 10.5))
                .foregroundStyle(soft)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)
            stripes
        }
        .foregroundStyle(AppColors.envelopeInk)
        .frame(width: ReportCardView.width)
        .background(AppColors.envelope)
    }

    // MARK: - Envelope

    /// The airmail border: red and blue bars on a slant.
    private var stripes: some View {
        ZStack {
            AirmailStripes(phase: 0).fill(AppColors.airmailRed)
            AirmailStripes(phase: 18).fill(AppColors.airmailBlue)
        }
        .frame(height: 10)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(report.name.isEmpty ? "Today’s post" : "From \(report.name)")
                    .font(.custom(bodoniItalic, size: 30))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(report.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.custom("Courier", size: 12.5))
                    .foregroundStyle(soft)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(report.done) of \(report.expected)")
                    .font(.custom(bodoni, size: 28))
                Text("Postmarked")
                    .font(.custom("Courier", size: 10))
                    .textCase(.uppercase)
                    .kerning(1.2)
                    .foregroundStyle(soft)
            }
        }
    }

    // MARK: - A stamp

    private func stamp(_ item: DailyReport.Item) -> some View {
        let ink = Color(hex: item.colorHex).mix(with: .black, by: 0.3)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if options.showStreaks {
                    Text("\(item.streak)")
                        .font(.custom(bodoni, size: 26))
                    Text(item.streakUnit)
                        .font(.custom("Courier-Bold", size: 8))
                        .textCase(.uppercase)
                }
            }
            .frame(height: 26, alignment: .bottom)
            Spacer(minLength: 0)
            Image(systemName: item.symbol)
                .font(.system(size: 26, weight: .regular))
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text(item.title)
                .font(.custom("Courier-Bold", size: 9))
                .textCase(.uppercase)
                .kerning(0.5)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(ink, in: .rect(cornerRadius: 2))
        .opacity(item.isDone ? 1 : 0.62)
        .padding(7)
        .background(AppColors.stampPaper)
        // Dots of envelope over the paper's edge: the perforations.
        .overlay {
            Rectangle().strokeBorder(AppColors.envelope, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [0, 8]))
        }
        .frame(width: stampSize.width, height: stampSize.height)
        .overlay(alignment: .topTrailing) {
            if item.isDone {
                Postmark(day: report.date)
                    .offset(x: 18, y: 30)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.isDone ? "done" : "not done")")
    }

    // MARK: - Customs

    private func customs(_ lines: [HealthLine]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Customs declaration")
                Spacer(minLength: 8)
                Text("Contents")
            }
            .font(.custom("Courier-Bold", size: 9))
            .textCase(.uppercase)
            .kerning(1)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(AppColors.envelopeInk).frame(height: 1) }
            ForEach(lines, id: \.self) { line in
                HStack {
                    Text(line.label)
                        .padding(.leading, line.isPart ? 12 : 0)
                    Spacer(minLength: 8)
                    Text(line.value)
                }
                .font(.custom(line.isPart ? "Courier" : "Courier-Bold", size: 11))
                .foregroundStyle(line.isPart ? soft : AppColors.envelopeInk)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.stampPaper)
        .overlay { Rectangle().strokeBorder(AppColors.envelopeInk, lineWidth: 1) }
    }
}

// MARK: - Shapes

/// The day's postmark: three wavy cancel lines into a ring with the weekday
/// and date, inked at a slant.
private struct Postmark: View {
    let day: Date

    var body: some View {
        ZStack(alignment: .leading) {
            CancelWaves()
                .stroke(AppColors.envelopeInk, lineWidth: 1.6)
                .frame(width: 46, height: 28)
            Circle()
                .stroke(AppColors.envelopeInk, lineWidth: 1.6)
                .frame(width: 40, height: 40)
                .overlay {
                    VStack(spacing: 1) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        Text(day.formatted(.dateTime.month(.abbreviated).day()))
                    }
                    .font(.custom("Courier-Bold", size: 7.5))
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.envelopeInk)
                }
                .offset(x: 44)
        }
        .frame(width: 86, height: 44, alignment: .leading)
        .rotationEffect(.degrees(-14))
        .opacity(0.8)
    }
}

/// Three wavy lines, evenly spaced down their frame.
private struct CancelWaves: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let wave = rect.width / 4
        for line in 0..<3 {
            let y = rect.minY + rect.height * CGFloat(line + 1) / 4
            path.move(to: CGPoint(x: rect.minX, y: y))
            for step in 0..<4 {
                let x = rect.minX + wave * CGFloat(step)
                path.addQuadCurve(
                    to: CGPoint(x: x + wave, y: y),
                    control: CGPoint(x: x + wave / 2, y: y + (step.isMultiple(of: 2) ? -4 : 4))
                )
            }
        }
        return path
    }
}

/// Bars on a slant across the frame, ten points wide every 36, starting
/// `phase` points in: one colour's share of an airmail border.
private struct AirmailStripes: Shape {
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let period: CGFloat = 36
        let bar: CGFloat = 10
        var x = rect.minX - rect.height - period + phase
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + bar, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + bar + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.closeSubpath()
            x += period
        }
        return path
    }
}
