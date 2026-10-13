import SwiftUI

// MARK: - Choice Chip

/// A one-of-many chip: a timer length, an interval. Selected is the solid
/// white pill with ink text; idle is the painted plate, because these sit on
/// cards (no glass on glass).
struct ChoiceChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isSelected else { return }
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? AppColors.inkOnLight : Color.white.opacity(0.85))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background {
                if isSelected {
                    Capsule().fill(AppColors.solidWhite)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1) }
                }
            }
            .frame(minHeight: AppLayout.minHitTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Templates

/// A rail of ready-made habits. One tap fills the form; the name stays
/// editable.
struct HabitTemplateRail: View {
    let onPick: (HabitTemplate) -> Void

    var body: some View {
        GlassSection("Start from a template") {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(HabitTemplate.all) { template in
                        Button {
                            onPick(template)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: template.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(hex: template.colorHex).glyphTone)
                                Text(template.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: AppLayout.minHitTarget)
                            .controlChrome(in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
        }
    }
}

// MARK: - Appearance

/// Colour and icon. The icon grid opens on the first row and expands on demand.
struct HabitAppearanceSection: View {
    @Binding var draft: HabitDraft
    @State private var showAllIcons = false

    static let symbols: [String] = [
        "book.fill", "figure.run", "drop.fill", "leaf.fill", "moon.fill", "sun.max.fill",
        "brain.head.profile", "dumbbell.fill", "heart.fill", "music.note", "pianokeys", "pencil",
        "fork.knife", "bed.double.fill", "figure.walk", "timer", "flame.fill", "bolt.fill",
        "star.fill", "trophy.fill", "bicycle", "figure.yoga", "pills.fill", "cup.and.saucer.fill",
        "paintbrush.fill", "camera.fill", "gamecontroller.fill", "laptopcomputer", "figure.hiking", "figure.stand",
        "figure.stairs", "phone.fill", "graduationcap.fill", "dollarsign.circle.fill", "house.fill", "pawprint.fill",
        "guitars.fill", "globe", "sparkles", "hand.raised.fill", "nosign", "circle.hexagongrid",
    ]

    var body: some View {
        GlassSection("Look") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                        ForEach(AppColors.tilePalette, id: \.hexString) { swatch in
                            colorButton(swatch)
                        }
                    }

                    MetricRowDivider()

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(visibleSymbols, id: \.self) { symbol in
                            symbolButton(symbol)
                        }
                    }

                    Button {
                        Haptics.light()
                        withAnimation(AppMotion.settle) { showAllIcons.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showAllIcons ? "Fewer icons" : "More icons")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .rotationEffect(.degrees(showAllIcons ? -180 : 0))
                        }
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: AppLayout.minHitTarget)
                    }
                    .buttonStyle(.textLink)
                }
            }
        }
    }

    /// The first row, plus the chosen icon if it lives further down.
    private var visibleSymbols: [String] {
        if showAllIcons { return Self.symbols }
        var row = Array(Self.symbols.prefix(12))
        if !row.contains(draft.symbol) {
            row[row.count - 1] = draft.symbol
        }
        return row
    }

    private func colorButton(_ swatch: Color) -> some View {
        let hex = swatch.hexString
        let isSelected = draft.colorHex == hex
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            draft.colorHex = hex
        } label: {
            Circle()
                .fill(swatch)
                .frame(width: 30, height: 30)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.white, lineWidth: 2.5)
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Colour \(hex)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = draft.symbol == symbol
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            draft.symbol = symbol
        } label: {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(isSelected ? AppColors.inkOnLight : Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    // Only the choice is painted; the rest are bare glyphs.
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                            .fill(AppColors.solidWhite)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Track by

/// Manual, timer or Apple Health, and the one setting each needs.
struct HabitTrackSection: View {
    @Binding var draft: HabitDraft
    @FocusState private var targetFocused: Bool

    private static let timerOptions: [Int] = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        GlassSection("Track by") {
            VStack(alignment: .leading, spacing: 12) {
                SectionPicker(
                    sections: HabitTrackKind.allCases,
                    selection: Binding(get: { draft.kind }, set: { draft.setKind($0) }),
                    label: { $0.label },
                    icon: { $0.symbol },
                    style: .compact
                )

                switch draft.kind {
                case .manual:
                    EmptyView()
                case .timer:
                    timerCard
                case .health:
                    healthCard
                }
            }
        }
    }

    private var timerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Timer length")
                    .font(.subheadline.weight(.semibold))
                FlowLayout(spacing: 8) {
                    ForEach(Self.timerOptions, id: \.self) { minutes in
                        ChoiceChip(title: "\(minutes) min", isSelected: draft.timerDurationSeconds == minutes * 60) {
                            draft.timerDurationSeconds = minutes * 60
                        }
                    }
                }
            }
        }
    }

    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(HealthKitSource.allCases.filter { $0 != .none }) { source in
                        metricButton(source)
                    }
                }

                MetricRowDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.frequency == .weekly ? "Weekly target" : "Daily target")
                            .font(.subheadline.weight(.semibold))
                        Text("Logs itself when reached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("", value: $draft.targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.statValue)
                            .multilineTextAlignment(.trailing)
                            .focused($targetFocused)
                            .frame(width: 80)
                        let unit = draft.source.unitSuffix.trimmingCharacters(in: .whitespaces)
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .inputWell(isFocused: targetFocused)
                }
            }
        }
    }

    private func metricButton(_ source: HealthKitSource) -> some View {
        let isSelected = draft.source == source
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            draft.setSource(source)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: source.symbol)
                    .font(.body)
                Text(source.label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? AppColors.inkOnLight : Color.white.opacity(0.75))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                    .fill(isSelected ? AppColors.solidWhite : Color.white.opacity(0.06))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Schedule

/// Daily, a weekly target, or every N days (manual habits only).
struct HabitScheduleSection: View {
    @Binding var draft: HabitDraft

    private static let intervalOptions: [Int] = [2, 3, 4, 5, 6, 7, 10, 14, 21, 30]

    private var options: [HabitFrequency] {
        draft.kind == .manual ? HabitFrequency.allCases : [.daily, .weekly]
    }

    var body: some View {
        GlassSection("Schedule") {
            VStack(alignment: .leading, spacing: 12) {
                SectionPicker(
                    sections: options,
                    selection: Binding(get: { draft.frequency }, set: { draft.setFrequency($0) }),
                    label: { $0.shortLabel },
                    style: .compact
                )

                switch draft.frequency {
                case .daily:
                    EmptyView()
                case .weekly:
                    if draft.kind != .health {
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(draft.weeklyTarget)× per week")
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                    Text("Any days you like")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Stepper("Times per week", value: $draft.weeklyTarget, in: 1...7)
                                    .labelsHidden()
                            }
                        }
                    }
                case .interval:
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Every")
                                .font(.subheadline.weight(.semibold))
                            FlowLayout(spacing: 8) {
                                ForEach(Self.intervalOptions, id: \.self) { days in
                                    ChoiceChip(title: "\(days) days", isSelected: draft.intervalDays == days) {
                                        draft.intervalDays = days
                                    }
                                }
                            }
                            Text("Slide to log any time. Logging restarts the countdown.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reminder

/// One reminder per habit. By default it learns: once a few logs exist it
/// fires `ReminderTiming.leadMinutes` before the habit is usually logged, and
/// the set time covers the days before that. Permission is asked the moment
/// the switch turns on, never at launch.
struct HabitReminderSection: View {
    @Binding var draft: HabitDraft
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        GlassSection("Reminder") {
            GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                SettingsRow("Remind me", icon: "bell", caption: caption, isOn: $draft.reminderEnabled)
                if draft.reminderEnabled {
                    if canLearn {
                        SettingsRow("Learn my time", icon: "sparkles", caption: learnCaption, isOn: $draft.reminderLearnsTime)
                    }
                    if let learned = shownLearnedTime {
                        SettingsRow("Time", icon: "clock") {
                            Text(learned.label)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        SettingsRow(isLearning ? "Until then" : "Time", icon: "clock") {
                            DatePicker("Reminder time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
            }
            .motion(AppMotion.settle, value: draft.reminderEnabled)
            .motion(AppMotion.settle, value: draft.reminderLearnsTime)
            .onChange(of: draft.reminderEnabled) { _, isOn in
                // iOS silently denies repeat prompts after a refusal, so ask
                // at the moment of intent.
                if isOn && !notifications.isAuthorized {
                    Task { await notifications.requestAuthorization() }
                }
            }
        }
    }

    /// Health habits log themselves from Apple Health, so their log times say
    /// nothing about the person's routine.
    private var canLearn: Bool { draft.kind != .health }

    private var isLearning: Bool { canLearn && draft.reminderLearnsTime }

    private var shownLearnedTime: ReminderTime? {
        isLearning ? draft.learnedReminderTime : nil
    }

    private var caption: String {
        guard draft.reminderEnabled else { return "Off" }
        switch draft.frequency {
        case .daily, .weekly: return "Every day"
        case .interval: return "On each due date"
        }
    }

    private var learnCaption: String {
        let lead = "\(ReminderTiming.leadMinutes) min before you usually log"
        guard draft.reminderLearnsTime else { return "Always the time below" }
        if draft.learnedReminderTime != nil { return lead }
        return "After \(ReminderTiming.minimumLogs) logs, \(lead)"
    }
}
