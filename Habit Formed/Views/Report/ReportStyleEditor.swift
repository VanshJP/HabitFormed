import SwiftData
import SwiftUI

/// What goes on the report card and how it looks: the habits and details,
/// the Apple Health numbers, then the layout as pictures, the background, the
/// accent and the type. What is on the card leads, since it changes from day
/// to day while the look is set once. It reads and writes the stored choices
/// itself, so Settings → Report card and the sheet's Edit are one editor, and
/// the card above it redraws as each one changes.
struct ReportStyleEditor: View {
    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @AppStorage(AppPreferences.reportLayout) private var layoutRaw = ReportLayout.list.rawValue
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
            healthSection
            GlassSection("Layout") {
                Panel {
                    SketchPicker(
                        items: ReportLayout.allCases,
                        selection: Binding(get: { layout }, set: { layoutRaw = $0.rawValue }),
                        name: \.title
                    ) { ReportLayoutSketch(layout: $0, accent: palette.accent) }
                }
            }
            GlassSection("Background") {
                ReportThemeRow(themeRaw: $themeRaw)
            }
            GlassSection("Accent") {
                Panel { accentGrid }
            }
            GlassSection("Type") {
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
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
        .motion(AppMotion.settle, value: layoutRaw)
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

    /// The habits first, then what each one carries. Notes and the week's
    /// dots live in a row, so they are offered only in the list layout.
    private var contentsSection: some View {
        GlassSection("On the card") {
            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    FlowLayout(spacing: 8) {
                        ForEach(habits) { habit in
                            ToggleChip(title: habit.title, icon: habit.symbol, tint: habit.color, isOn: includes(habit))
                        }
                    }
                    FlowLayout(spacing: 8) {
                        ToggleChip(title: "Streaks", icon: "flame", isOn: $showStreaks)
                        if layout.showsRowDetail {
                            ToggleChip(title: "Habit notes", icon: "text.quote", isOn: $showNotes)
                            ToggleChip(title: "Last 7 days", icon: "circle.grid.3x3", isOn: $showWeek)
                        }
                    }
                }
            }
        }
    }

    /// One chip per number, so what is picked is exactly what the card adds.
    private var healthSection: some View {
        GlassSection("Apple Health") {
            GlassEffectContainer(spacing: 8) {
                FlowLayout(spacing: 8) {
                    ForEach(ReportMetric.allCases) { metric in
                        ToggleChip(title: metric.title, icon: metric.icon, isOn: shows(metric))
                    }
                }
            }
        }
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

/// A report layout in miniature: rows under a ring, squares under a ring, or
/// one big ring over a strip of dots.
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
        }
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
