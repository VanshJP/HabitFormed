import SwiftUI

// MARK: - Ideas

/// Ready-made habits: one tap fills the form, and the name stays editable.
/// A rail at first; "Show all" wraps every idea into view. The one picked
/// stays lit.
struct HabitIdeas: View {
    let pickedTitle: String
    let onPick: (HabitTemplate) -> Void

    @State private var showAll = false

    var body: some View {
        GlassSection("Ideas") {
            if showAll {
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) { chips }
                }
            } else {
                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) { chips }
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
                .padding(.horizontal, -AppLayout.pageHorizontal)
            }
        } accessory: {
            Button {
                Haptics.light()
                withAnimation(AppMotion.settle) { showAll.toggle() }
            } label: {
                HeaderLinkLabel(showAll ? "Fewer" : "Show all", icon: showAll ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.textLink)
            .accessibilityLabel(showAll ? "Show fewer ideas" : "Show all ideas")
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(HabitTemplate.all) { template in
            ChoiceChip(
                title: template.title,
                icon: template.symbol,
                tint: Color(hex: template.colorHex),
                isSelected: template.title == pickedTitle
            ) {
                onPick(template)
            }
        }
    }
}

// MARK: - Appearance

/// Colour and icon, inside the name card once opened. The icons open on
/// two rows and expand on demand.
struct HabitLookPicker: View {
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
        .padding(14)
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

// MARK: - How do you log it?

/// Check off, timer or Apple Health, and the one setting each needs.
struct HabitTrackSection: View {
    @Binding var draft: HabitDraft
    @FocusState private var targetFocused: Bool

    private static let timerOptions: [Int] = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        GlassSection("How do you log it?") {
            VStack(alignment: .leading, spacing: 10) {
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(HabitTrackKind.allCases) { kind in
                            ChoiceChip(title: kind.label, icon: kind.symbol, isSelected: draft.kind == kind) {
                                withAnimation(AppMotion.settle) { draft.setKind(kind) }
                            }
                        }
                    }
                }

                switch draft.kind {
                case .manual:
                    EmptyView()
                case .timer:
                    timerPanel
                case .health:
                    healthPanel
                }
            }
        }
    }

    private var timerPanel: some View {
        Panel {
            FlowLayout(spacing: 8) {
                ForEach(Self.timerOptions, id: \.self) { minutes in
                    ChoiceChip(title: "\(minutes) min", isSelected: draft.timerDurationSeconds == minutes * 60) {
                        draft.timerDurationSeconds = minutes * 60
                    }
                }
            }
            .padding(12)
        }
    }

    private var healthPanel: some View {
        Panel {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(HealthKitSource.allCases.filter { $0 != .none }) { source in
                    metricButton(source)
                }
            }
            .padding(12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.frequency == .weekly ? "Goal a week" : "Goal a day")
                        .font(.subheadline.weight(.semibold))
                    Text("Checks itself off when you get there")
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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

// MARK: - How often?

/// Every day, some times a week, or every few days (checked-off habits only).
struct HabitScheduleSection: View {
    @Binding var draft: HabitDraft

    private static let intervalOptions: [Int] = [2, 3, 4, 5, 6, 7, 10, 14, 21, 30]

    private var options: [HabitFrequency] {
        draft.kind == .manual ? HabitFrequency.allCases : [.daily, .weekly]
    }

    var body: some View {
        GlassSection("How often?") {
            VStack(alignment: .leading, spacing: 10) {
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(options) { frequency in
                            ChoiceChip(title: frequency.shortLabel, isSelected: draft.frequency == frequency) {
                                withAnimation(AppMotion.settle) { draft.setFrequency(frequency) }
                            }
                        }
                    }
                }

                switch draft.frequency {
                case .daily:
                    EmptyView()
                case .weekly:
                    if draft.kind != .health {
                        Panel {
                            HStack {
                                Text(draft.weeklyTarget == 1 ? "Once a week" : "\(draft.weeklyTarget) times a week")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                Spacer()
                                Stepper("Times a week", value: $draft.weeklyTarget, in: 1...7)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                case .interval:
                    Panel {
                        VStack(alignment: .leading, spacing: 8) {
                            FlowLayout(spacing: 8) {
                                ForEach(Self.intervalOptions, id: \.self) { days in
                                    ChoiceChip(title: "\(days) days", isSelected: draft.intervalDays == days) {
                                        draft.intervalDays = days
                                    }
                                }
                            }
                            Text("Counts from your last log.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 2)
                        }
                        .padding(12)
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
            Panel {
                SettingsRow("Remind me", icon: "bell", isOn: $draft.reminderEnabled)
                if draft.reminderEnabled {
                    SettingsRow("Time", icon: "clock") {
                        if let learned = shownLearnedTime {
                            Text(learned.label)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            DatePicker("Reminder time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    if canLearn {
                        SettingsRow("Match my routine", icon: "sparkles", caption: learnCaption, isOn: $draft.reminderLearnsTime)
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

    private var shownLearnedTime: ReminderTime? {
        canLearn && draft.reminderLearnsTime ? draft.learnedReminderTime : nil
    }

    private var learnCaption: String {
        let lead = "\(ReminderTiming.leadMinutes) min before you usually log"
        guard draft.reminderLearnsTime else { return "Always at this time" }
        if draft.learnedReminderTime != nil { return lead }
        return "After \(ReminderTiming.minimumLogs) logs, \(lead)"
    }
}
