import SwiftData
import SwiftUI

/// The studio's Content tools: your name, kept for every card, this card's
/// note, then a band of chips each for the habits, what each one carries,
/// and the Apple Health numbers, so what is picked is exactly what shows.
struct ReportContentTool: View {
    let scope: ReportScope
    let layout: ReportLayout
    /// This card's note, or nil in Settings, where there is no card to send.
    let note: Binding<String>?

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""
    @AppStorage(AppPreferences.reportShowStreaks) private var showStreaks = true
    @AppStorage(AppPreferences.reportShowNotes) private var showNotes = true
    @AppStorage(AppPreferences.reportShowWeek) private var showWeek = true
    @AppStorage(AppPreferences.reportMetrics) private var metricsRaw = ReportOptions.legacyMetricsRaw

    var body: some View {
        Panel(dividerInset: AppLayout.tilePadding) {
            SettingsRow("Name", icon: "person") {
                TextField("", text: $reporterName, prompt: Text("Add").foregroundStyle(.white.opacity(0.4)))
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
            if let note {
                ReportNoteField(note: note)
            }
            if !habits.isEmpty {
                chipBand {
                    ForEach(habits) { habit in
                        ToggleChip(title: habit.title, icon: habit.symbol, tint: habit.color, isOn: includes(habit))
                    }
                }
            }
            if showsDetails {
                chipBand {
                    ToggleChip(title: "Streaks", icon: "flame", isOn: $showStreaks)
                    if scope == .day, layout.showsHabitNotes {
                        ToggleChip(title: "Habit notes", icon: "text.quote", isOn: $showNotes)
                    }
                    if scope == .day, layout.showsWeekDots {
                        ToggleChip(title: "Last 7 days", icon: "circle.grid.3x3", isOn: $showWeek)
                    }
                }
            }
            if scope == .day {
                chipBand {
                    ForEach(ReportMetric.allCases) { metric in
                        ToggleChip(title: metric.title, icon: metric.icon, isOn: shows(metric))
                    }
                }
            }
        }
    }

    /// The week prints its longest run whatever this says, and Minimal
    /// prints no runs at all.
    private var showsDetails: Bool {
        switch scope {
        case .day: return layout != .minimal
        case .week: return false
        case .year: return true
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

/// The studio's Style tools: the background, the accent and the type, each
/// only where the card shows it. Every card shares them, so the day, the
/// week and the year look like one set.
struct ReportStyleTool: View {
    let scope: ReportScope
    let layout: ReportLayout

    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @AppStorage(AppPreferences.reportAccent) private var accentHex = ""
    @AppStorage(AppPreferences.reportFont) private var fontRaw = ReportFont.standard.rawValue

    @Environment(\.appCanvas) private var canvas

    private var look: CanvasLook? { (ReportTheme(rawValue: themeRaw) ?? .app).look(appLook: canvas.look) }

    var body: some View {
        // A layout with paper of its own (a front page, an envelope) prints
        // the same whatever these say; the receipt lies on the background
        // and its store mark takes the accent.
        let ownsLook = scope == .day && layout.ownsLook
        VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            if !ownsLook || layout.showsBackground {
                GlassSection("Background") {
                    ReportThemeRow(themeRaw: $themeRaw)
                }
            }
            if !ownsLook || layout == .receipt {
                GlassSection("Accent") { accentRail }
            }
            if !ownsLook {
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
            if ownsLook, !layout.showsBackground {
                Text("\(layout.title) brings its own paper, ink and type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Accent

    /// The background's own accent first, then the habit palette, in one
    /// row that scrolls.
    private var accentRail: some View {
        let palette = ReportPalette(look: look, accentHex: accentHex)
        let own = ReportPalette(look: look).accent
        return ScrollView(.horizontal) {
            HStack(spacing: 0) {
                accentDot(hex: "", fill: own, label: "Match the background")
                ForEach(AppColors.tilePalette, id: \.hexString) { color in
                    accentDot(hex: color.hexString, fill: palette.isLight ? color : color.glyphTone, label: "Accent \(color.hexString)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, AppLayout.pageHorizontal - 7, for: .scrollContent)
        .padding(.horizontal, -AppLayout.pageHorizontal)
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
}
