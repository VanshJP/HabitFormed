import SwiftData
import SwiftUI

/// Everything about the report card in one place: your name and what goes
/// on the card, then the layout as pictures, the background, the accent and
/// the type. What is on the card leads, since it changes from day to day
/// while the look is set once. It reads and writes the stored choices
/// itself, so Settings → Report style and the sheet's Edit are one editor,
/// every card and recap after carries them, and the card above it redraws
/// as each one changes.
struct ReportStyleEditor: View {
    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @AppStorage(AppPreferences.reportLayout) private var layoutRaw = ReportLayout.list.rawValue
    @AppStorage(AppPreferences.reportRing) private var ringRaw = ReportRing.big.rawValue
    @AppStorage(AppPreferences.reportAccent) private var accentHex = ""
    @AppStorage(AppPreferences.reportFont) private var fontRaw = ReportFont.standard.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""
    @AppStorage(AppPreferences.reportShowStreaks) private var showStreaks = true
    @AppStorage(AppPreferences.reportShowNotes) private var showNotes = true
    @AppStorage(AppPreferences.reportShowWeek) private var showWeek = true
    @AppStorage(AppPreferences.reportMetrics) private var metricsRaw = ReportOptions.legacyMetricsRaw

    @Environment(\.appCanvas) private var canvas

    private var theme: ReportTheme { ReportTheme(rawValue: themeRaw) ?? .app }
    private var look: CanvasLook? { theme.look(appLook: canvas.look) }
    private var layout: ReportLayout { ReportLayout(rawValue: layoutRaw) ?? .list }
    private var palette: ReportPalette { ReportPalette(look: look, accentHex: accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            contentsSection
            GlassSection("Layout") {
                Panel {
                    SketchPicker(
                        items: ReportLayout.allCases,
                        selection: Binding(get: { layout }, set: { layoutRaw = $0.rawValue }),
                        name: \.title
                    ) { ReportLayoutSketch(layout: $0, accent: palette.accent) }
                    if layout.showsRing {
                        SettingsRow("Ring", icon: "circle.dashed") {
                            ForEach(ReportRing.allCases) { ring in
                                ChoiceChip(title: ring.title, isSelected: ringRaw == ring.rawValue) {
                                    ringRaw = ring.rawValue
                                }
                            }
                        }
                    }
                }
            }
            // A layout with a look of its own (a front page, an envelope)
            // prints the same whatever these say; the receipt's store mark
            // still takes the accent.
            if !layout.ownsLook {
                GlassSection("Background") {
                    ReportThemeRow(themeRaw: $themeRaw)
                }
            }
            if !layout.ownsLook || layout == .receipt {
                GlassSection("Accent") {
                    Panel { accentGrid }
                }
            }
            if !layout.ownsLook {
                typeSection
            }
        }
        .motion(AppMotion.settle, value: layoutRaw)
    }

    private var typeSection: some View {
        GlassSection("Type") {
            GlassEffectContainer(spacing: 8) {
                FlowLayout.chips {
                    ForEach(ReportFont.allCases) { font in
                        ChoiceChip(title: font.title, isSelected: fontRaw == font.rawValue) {
                            fontRaw = font.rawValue
                        }
                        .fontDesign(font.design)
                    }
                }
            }
        }
    }

    // MARK: - Accent

    /// The background's own accent first, then the habit palette.
    private var accentGrid: some View {
        let own = ReportPalette(look: look).accent
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
            accentDot(hex: "", fill: own, label: "Match the background")
            ForEach(AppColors.tilePalette, id: \.hexString) { color in
                accentDot(hex: color.hexString, fill: palette.isLight ? color : color.glyphTone, label: "Accent \(color.hexString)")
            }
        }
        .padding(AppLayout.tilePadding)
    }

    private func accentDot(hex: String, fill: Color, label: String) -> some View {
        let isSelected = accentHex == hex
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            accentHex = hex
        } label: {
            Circle()
                .fill(fill)
                .frame(width: 30, height: 30)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.white, lineWidth: 2.5)
                    }
                    // The background's own accent is marked so it reads as
                    // "automatic", not as one more colour.
                    if hex.isEmpty {
                        Image(systemName: "wand.and.sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - On the card

    /// One panel of what the card carries: your name, kept for every card
    /// and recap, then a band each for the habits, what each one carries,
    /// and one chip per Apple Health number, so what is picked is exactly
    /// what the card adds. Notes and the week's dots live in a row, so they
    /// are offered only in the list layout.
    private var contentsSection: some View {
        GlassSection("On the card") {
            Panel(dividerInset: AppLayout.tilePadding) {
                SettingsRow("Name", icon: "person") {
                    TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                }
                if !habits.isEmpty {
                    chipBand {
                        ForEach(habits) { habit in
                            ToggleChip(title: habit.title, icon: habit.symbol, tint: habit.color, isOn: includes(habit))
                        }
                    }
                }
                chipBand {
                    ToggleChip(title: "Streaks", icon: "flame", isOn: $showStreaks)
                    if layout.showsRowDetail {
                        ToggleChip(title: "Habit notes", icon: "text.quote", isOn: $showNotes)
                        ToggleChip(title: "Last 7 days", icon: "circle.grid.3x3", isOn: $showWeek)
                    }
                }
                chipBand {
                    ForEach(ReportMetric.allCases) { metric in
                        ToggleChip(title: metric.title, icon: metric.icon, isOn: shows(metric))
                    }
                }
            }
        }
    }

    /// A band of chips on the panel. Their hit frames sit 5pt clear of the
    /// capsules, so the capsules land a tile's padding from the hairlines,
    /// as they do from the panel's edges.
    private func chipBand<Chips: View>(@ViewBuilder _ chips: () -> Chips) -> some View {
        FlowLayout.chips { chips() }
            .padding(.horizontal, AppLayout.tilePadding)
            .padding(.vertical, AppLayout.tilePadding - 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shows(_ metric: ReportMetric) -> Binding<Bool> {
        Binding(
            get: { ReportOptions.metrics(from: metricsRaw).contains(metric) },
            set: { isOn in
                var metrics = ReportOptions.metrics(from: metricsRaw)
                if isOn { metrics.insert(metric) } else { metrics.remove(metric) }
                metricsRaw = ReportOptions.raw(from: metrics)
            }
        )
    }

    private func includes(_ habit: Habit) -> Binding<Bool> {
        Binding(
            get: { !ReportOptions.hiddenIDs(from: hiddenRaw).contains(habit.id) },
            set: { isOn in
                var hidden = ReportOptions.hiddenIDs(from: hiddenRaw)
                if isOn { hidden.remove(habit.id) } else { hidden.insert(habit.id) }
                hiddenRaw = ReportOptions.raw(from: hidden)
            }
        )
    }
}

/// A report layout in miniature: rows under a ring, squares under a ring, a
/// board of days, rings in rings, one big ring over a strip of dots, dots
/// orbiting a ring, a dial, stems in a row, joined stars, a honeycomb, a
/// front page, a punch card, stamps, or a slip of paper.
private struct ReportLayoutSketch: View {
    let layout: ReportLayout
    let accent: Color

    private let faint = Color.white.opacity(0.14)

    var body: some View {
        switch layout {
        case .list:
            VStack(alignment: .leading, spacing: 4) {
                ring(14)
                bar(true); bar(false); bar(true)
            }
        case .grid:
            VStack(alignment: .leading, spacing: 4) {
                ring(14)
                HStack(spacing: 4) { square(true); square(false); square(true) }
                HStack(spacing: 4) { square(false); square(true); square(false) }
            }
        case .focus:
            VStack(spacing: 5) {
                ring(28)
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle().fill(index.isMultiple(of: 2) ? accent : faint).frame(width: 7, height: 7)
                    }
                }
            }
        case .week:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 3) {
                        Capsule().fill(faint).frame(width: 12, height: 5)
                        ForEach(0..<5, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill((row + day * 2) % 3 == 0 ? faint : accent)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
        case .rings:
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let size = CGFloat(36 - index * 10)
                    Circle()
                        .stroke(faint, lineWidth: 3)
                        .frame(width: size, height: size)
                    Circle()
                        .trim(from: 0, to: [0.85, 0.5, 0.7][index])
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size, height: size)
                }
            }
        case .orbit:
            ZStack {
                ring(16)
                ForEach(0..<6, id: \.self) { index in
                    let angle = CGFloat(index) / 6 * 2 * .pi - .pi / 2
                    Circle()
                        .fill(index.isMultiple(of: 2) ? accent : faint)
                        .frame(width: 7, height: 7)
                        .offset(x: 17 * cos(angle), y: 17 * sin(angle))
                }
            }
            .frame(width: 42, height: 42)
        case .sundial:
            ZStack {
                Circle()
                    .stroke(faint, lineWidth: 3)
                Circle()
                    .trim(from: 0.92, to: 1)
                    .stroke(accent.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                ForEach([0.3, 0.42, 0.55, 0.78], id: \.self) { (fraction: Double) in
                    let angle = fraction * 2 * .pi - .pi / 2
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 20 * cos(angle), y: 20 * sin(angle))
                }
            }
            .frame(width: 40, height: 40)
        case .garden:
            let plants: [(height: CGFloat, done: Bool)] = [(22, true), (12, false), (28, true), (18, true)]
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(plants.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        Circle()
                            .fill(plants[index].done ? accent : faint)
                            .frame(width: 8, height: 8)
                        Capsule()
                            .fill(faint)
                            .frame(width: 2, height: plants[index].height)
                    }
                }
            }
            .overlay(alignment: .bottom) { Capsule().fill(faint).frame(width: 50, height: 2) }
        case .constellation:
            let stars: [CGPoint] = [CGPoint(x: 6, y: 30), CGPoint(x: 18, y: 12), CGPoint(x: 33, y: 22), CGPoint(x: 46, y: 6)]
            ZStack(alignment: .topLeading) {
                Path { path in path.addLines(Array(stars.prefix(3))) }
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                Path { path in path.addLines(Array(stars.suffix(2))) }
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                ForEach(stars.indices, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? accent : faint)
                        .frame(width: index < 3 ? 7 : 5, height: index < 3 ? 7 : 5)
                        .position(stars[index])
                }
            }
            .frame(width: 52, height: 36)
        case .frontPage:
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(AppColors.newsInk).frame(width: 30, height: 4)
                Rectangle().fill(AppColors.newsInk).frame(height: 1.5)
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 2.5) {
                        ForEach([1, 0.7, 0.85], id: \.self) { (share: Double) in
                            Capsule().fill(AppColors.newsInk.opacity(0.45)).frame(width: 16 * share, height: 2)
                        }
                    }
                    Rectangle().fill(AppColors.newsInk.opacity(0.3)).frame(width: 1, height: 12)
                    VStack(alignment: .leading, spacing: 2.5) {
                        ForEach([0.8, 1, 0.6], id: \.self) { (share: Double) in
                            Capsule().fill(AppColors.newsInk.opacity(0.45)).frame(width: 16 * share, height: 2)
                        }
                    }
                }
            }
            .padding(6)
            .background(AppColors.newsprint, in: .rect(cornerRadius: 2))
            .rotationEffect(.degrees(3))
        case .punchCard:
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { day in
                            Circle()
                                .fill((row + day) % 3 == 0 ? AppColors.kraft : AppColors.table)
                                .overlay { Circle().stroke(AppColors.kraftRule, lineWidth: 0.75) }
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding(6)
            .background(AppColors.kraft, in: .rect(cornerRadius: 4))
        case .stamps:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index == 1 ? faint : accent)
                        .padding(2.5)
                        .background(AppColors.stampPaper)
                        .overlay {
                            Rectangle().strokeBorder(AppColors.envelope, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 3.5]))
                        }
                        .frame(width: 14, height: 18)
                }
            }
            .padding(5)
            .background(AppColors.envelope, in: .rect(cornerRadius: 2))
        case .bubbles:
            VStack(spacing: -2) {
                HStack(spacing: 3) { bubble(true); bubble(false); bubble(true) }
                HStack(spacing: 3) { bubble(false); bubble(true) }
            }
        case .receipt:
            VStack(alignment: .leading, spacing: 3.5) {
                ForEach([1, 0.6, 0.8, 0.5], id: \.self) { share in
                    Capsule().fill(Color.black.opacity(0.4)).frame(width: 24 * share, height: 2.5)
                }
                Capsule().fill(accent).frame(width: 24, height: 3)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
            .background(Color(white: 0.94), in: ReceiptSlip(tooth: 5, depth: 2.5))
            .rotationEffect(.degrees(-4))
        }
    }

    private func bubble(_ done: Bool) -> some View {
        Circle()
            .fill(done ? accent : faint)
            .frame(width: 15, height: 15)
    }

    private func ring(_ size: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(accent, style: StrokeStyle(lineWidth: size / 6, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: size, height: size)
    }

    private func bar(_ done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(done ? accent.opacity(0.85) : faint)
            .frame(height: 6)
    }

    private func square(_ done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(done ? accent : faint)
            .frame(height: 13)
    }
}
