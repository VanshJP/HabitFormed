import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notifications

    var habit: Habit?

    // MARK: - State

    @State private var title: String = ""
    @State private var symbol: String = "circle.hexagongrid"
    @State private var colorHex: String = AppColors.tilePalette.first?.hexString ?? "#0D8488"
    @State private var frequency: HabitFrequency = .daily
    @State private var weeklyTarget: Int = 5
    @State private var intervalDays: Int = 3
    @State private var source: HealthKitSource = .none
    @State private var targetValue: Double = 1
    @State private var timerDurationSeconds: Int = 1500

    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()

    @State private var inputType: InputType = .manual
    @State private var appearanceExpanded: Bool = true

    @FocusState private var nameFocused: Bool

    // MARK: - Constants

    private static let symbols: [String] = [
        "book.fill", "figure.run", "drop.fill", "leaf.fill", "moon.fill",
        "sun.max.fill", "brain.head.profile", "dumbbell.fill", "heart.fill",
        "music.note", "pencil", "fork.knife", "bed.double.fill", "figure.walk",
        "timer", "flame.fill", "bolt.fill", "star.fill", "trophy.fill",
        "bicycle", "figure.yoga", "pills.fill", "cup.and.saucer.fill",
        "paintbrush.fill", "camera.fill", "gamecontroller.fill", "laptopcomputer",
        "figure.hiking", "figure.stand", "figure.stairs",
    ]

    private static let timerOptions: [(label: String, seconds: Int)] = [
        ("5m", 300), ("10m", 600), ("15m", 900), ("20m", 1200),
        ("25m", 1500), ("30m", 1800), ("45m", 2700), ("60m", 3600),
    ]

    private static let intervalDayOptions: [Int] = [2, 3, 4, 5, 6, 7, 10, 14, 21, 30]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(style: .subtle).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        typeSection
                        typeDetailSection
                        scheduleSection
                        reminderSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { Haptics.light(); dismiss() }
                        .foregroundStyle(.white.opacity(0.8))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadFromHabit()
                if habit == nil { nameFocused = true }
            }
            .onChange(of: inputType, handleTypeChange)
            .onChange(of: source) { _, new in
                if new != .none {
                    targetValue = frequency == .weekly ? new.weeklyDefaultTarget : new.defaultTarget
                }
            }
            .onChange(of: frequency) { _, newFreq in
                // Snap the health target to a sensible default when toggling
                // between daily and weekly so the user doesn't have to type
                // (e.g. 30 → 150 exercise minutes when going weekly).
                guard inputType == .health, source != .none else { return }
                targetValue = newFreq == .weekly ? source.weeklyDefaultTarget : source.defaultTarget
            }
        }
    }

    // MARK: - Header (preview + name + appearance)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: colorHex).opacity(0.28))
                        .frame(width: 64, height: 64)
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(hex: colorHex))
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Habit Name", text: $title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .focused($nameFocused)
                        .submitLabel(.done)
                    Text(previewSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer(minLength: 0)
            }

            Divider().opacity(0.16)

            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.3)) { appearanceExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: colorHex)).frame(width: 18, height: 18)
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Appearance")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(appearanceExpanded ? -180 : 0))
                }
            }
            .buttonStyle(.plain)

            if appearanceExpanded {
                HStack(spacing: 10) {
                    ForEach(AppColors.tilePalette, id: \.hexString) { color in
                        Button {
                            Haptics.selection()
                            colorHex = color.hexString
                        } label: {
                            ZStack {
                                Circle().fill(color).frame(width: 32, height: 32)
                                if colorHex == color.hexString {
                                    Circle().stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: colorHex)
                    }
                    Spacer(minLength: 0)
                }

                Divider().opacity(0.16)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(Self.symbols, id: \.self) { sym in
                        Button {
                            Haptics.selection()
                            symbol = sym
                            // After picking an icon the user has finished the
                            // appearance step, so collapse the section and
                            // keep focus on the name + type.
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.18)) {
                                appearanceExpanded = false
                            }
                        } label: {
                            Image(systemName: sym)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(symbol == sym
                                            ? Color(hex: colorHex).opacity(0.52)
                                            : Color.white.opacity(0.07))
                                }
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: symbol)
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, tint: Color(hex: colorHex).opacity(0.16))
        .animation(.spring(response: 0.3), value: colorHex)
        .animation(.spring(response: 0.3), value: symbol)
        .animation(.spring(response: 0.3), value: inputType)
        .animation(.spring(response: 0.3), value: appearanceExpanded)
    }

    // MARK: - Type picker

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionHeader("Track By", icon: "square.3.layers.3d")
            HStack(spacing: 8) {
                typeButton(.manual, icon: "hand.tap",   label: "Manual")
                typeButton(.timer,  icon: "timer",      label: "Timed")
                typeButton(.health, icon: "heart.fill", label: "Health")
            }
            .padding(12)
            .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
        }
    }

    private func typeButton(_ type: InputType, icon: String, label: String) -> some View {
        Button { Haptics.selection(); inputType = type } label: {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(inputType == type ? Color(hex: colorHex) : .white.opacity(0.35))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(inputType == type ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(inputType == type ? Color(hex: colorHex).opacity(0.22) : Color.white.opacity(0.06))
            }
            .animation(.spring(response: 0.25), value: inputType)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Type-specific config

    @ViewBuilder
    private var typeDetailSection: some View {
        switch inputType {
        case .manual:
            EmptyView()
        case .timer:
            timerDurationSection
        case .health:
            healthSection
        }
    }

    // Timer chips

    private var timerDurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionHeader("Duration", icon: "timer")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.timerOptions, id: \.seconds) { opt in
                        Button {
                            Haptics.selection()
                            timerDurationSeconds = opt.seconds
                        } label: {
                            Text(opt.label)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(timerDurationSeconds == opt.seconds ? .white : .white.opacity(0.52))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    Capsule()
                                        .fill(timerDurationSeconds == opt.seconds
                                            ? Color(hex: colorHex).opacity(0.75)
                                            : Color.white.opacity(0.08))
                                }
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: timerDurationSeconds)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
        }
    }

    // Health metric grid + target

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionHeader("Metric", icon: "heart.text.square.fill")
            VStack(spacing: 14) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(HealthKitSource.allCases.filter { $0 != .none }) { src in
                        healthMetricButton(src)
                    }
                }

                Divider().opacity(0.16)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(frequency == .weekly ? "Weekly Target" : "Daily Target")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(source.label)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("", value: $targetValue, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                        if !source.unitSuffix.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(source.unitSuffix.trimmingCharacters(in: .whitespaces))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
        }
    }

    private func healthMetricButton(_ src: HealthKitSource) -> some View {
        let isSelected = source == src
        return Button { Haptics.selection(); source = src } label: {
            VStack(spacing: 5) {
                Image(systemName: src.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? Color(hex: colorHex) : .white.opacity(0.38))
                Text(src.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: colorHex).opacity(0.22) : Color.white.opacity(0.06))
            }
            .animation(.spring(response: 0.25), value: source)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionHeader("Schedule", icon: "calendar")
            VStack(spacing: 12) {
                Picker("", selection: $frequency) {
                    ForEach(HabitFrequency.allCases) { f in
                        Text(f.shortLabel).tag(f)
                    }
                }
                .pickerStyle(.segmented)

                if frequency == .weekly && inputType != .health {
                    HStack {
                        Text("\(weeklyTarget)× per week")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $weeklyTarget, in: 1...7).labelsHidden()
                    }
                }

                if frequency == .interval {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.intervalDayOptions, id: \.self) { days in
                                Button {
                                    Haptics.selection()
                                    intervalDays = days
                                } label: {
                                    Text("\(days)d")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(intervalDays == days ? .white : .white.opacity(0.52))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule()
                                                .fill(intervalDays == days
                                                    ? Color(hex: colorHex).opacity(0.75)
                                                    : Color.white.opacity(0.08))
                                        }
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.25), value: intervalDays)
                            }
                        }
                    }

                    Text("Swipe to log any time. Logging restarts the countdown.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
            .animation(.spring(response: 0.3), value: frequency)
            .animation(.spring(response: 0.3), value: intervalDays)
        }
    }

    // MARK: - Reminder

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionHeader("Reminder", icon: "bell.badge.fill")
            VStack(spacing: 12) {
                Toggle(isOn: $reminderEnabled.animation(.spring(response: 0.3))) {
                    HStack(spacing: 10) {
                        Image(systemName: reminderEnabled ? "bell.fill" : "bell.slash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(reminderEnabled ? Color(hex: colorHex) : .white.opacity(0.4))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reminder")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(reminderEnabled
                                 ? reminderSubtitle
                                 : "Off")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                .tint(Color(hex: colorHex))
                .onChange(of: reminderEnabled) { _, isOn in
                    // Ask at the moment of intent rather than app launch;
                    // iOS silently denies repeat prompts after a refusal.
                    if isOn && !notifications.isAuthorized {
                        Task { await notifications.requestAuthorization() }
                    }
                }

                if reminderEnabled {
                    Divider().opacity(0.16)
                    HStack {
                        Text("Time")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16, tint: AppColors.glassTintAccent)
        }
    }

    // MARK: - Preview subtitle

    /// Explains when the reminder will actually fire for this cadence.
    private var reminderSubtitle: String {
        switch frequency {
        case .daily, .weekly:
            return "Every day at the time below"
        case .interval:
            return "On each due date at the time below"
        }
    }

    private var previewSubtitle: String {
        switch inputType {
        case .manual:
            switch frequency {
            case .daily:    return "Daily · Manual"
            case .weekly:   return "\(weeklyTarget)× / week · Manual"
            case .interval: return "Every \(intervalDays) days · Manual"
            }
        case .timer:
            switch frequency {
            case .daily:    return "\(timerDurationSeconds / 60)min · Daily"
            case .weekly:   return "\(timerDurationSeconds / 60)min · \(weeklyTarget)× / week"
            // Cadence leads for interval since the countdown is the primary cue.
            case .interval: return "Every \(intervalDays) days · \(timerDurationSeconds / 60)min"
            }
        case .health:
            guard source != .none else { return "Select a metric" }
            let val = source == .steps && targetValue >= 1000
                ? String(format: "%.0fk", targetValue / 1000)
                : "\(Int(targetValue))\(source.unitSuffix)"
            // Interval+health is transient (auto-resets to daily); read as "/ day".
            let cadence = frequency == .weekly ? " / week" : " / day"
            return "\(source.label) · \(val)\(cadence)"
        }
    }

    // MARK: - Actions

    private func loadFromHabit() {
        guard let habit else { return }
        title = habit.title
        symbol = habit.symbol
        colorHex = habit.colorHex
        frequency = habit.frequency
        weeklyTarget = habit.weeklyTarget
        intervalDays = habit.intervalDays
        source = habit.source
        targetValue = habit.targetValue
        timerDurationSeconds = habit.timerDurationSeconds > 0 ? habit.timerDurationSeconds : 1500

        reminderEnabled = habit.reminderEnabled
        if let date = Calendar.current.date(
            bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: Date()
        ) {
            reminderTime = date
        }

        if habit.source != .none {
            inputType = .health
        } else if habit.timerDurationSeconds > 0 {
            inputType = .timer
        } else {
            inputType = .manual
        }

        appearanceExpanded = false
    }

    private func handleTypeChange(_: InputType, _ new: InputType) {
        // Interval is a manual-swipe cadence, so snap back to daily
        // when the habit becomes timer- or HealthKit-tracked.
        if new != .manual && frequency == .interval {
            frequency = .daily
        }
        switch new {
        case .manual:
            break
        case .timer:
            source = .none
            if timerDurationSeconds == 0 { timerDurationSeconds = 1500 }
        case .health:
            timerDurationSeconds = 0
            if source == .none { source = .steps }
            targetValue = source.defaultTarget
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let finalSource = inputType == .health ? source : HealthKitSource.none
        let finalTimer  = inputType == .timer  ? timerDurationSeconds : 0
        let finalTarget = inputType == .health ? targetValue : 1.0

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = comps.hour ?? 9
        let minute = comps.minute ?? 0

        if let habit {
            habit.title = trimmed
            habit.symbol = symbol
            habit.colorHex = colorHex
            habit.frequencyRaw = frequency.rawValue
            habit.weeklyTarget = weeklyTarget
            habit.intervalDays = intervalDays
            habit.sourceRaw = finalSource.rawValue
            habit.targetValue = finalTarget
            habit.timerDurationSeconds = finalTimer
            habit.reminderEnabled = reminderEnabled
            habit.reminderHour = hour
            habit.reminderMinute = minute
        } else {
            modelContext.insert(Habit(
                title: trimmed,
                symbol: symbol,
                colorHex: colorHex,
                frequency: frequency,
                weeklyTarget: weeklyTarget,
                intervalDays: intervalDays,
                source: finalSource,
                targetValue: finalTarget,
                timerDurationSeconds: finalTimer,
                reminderEnabled: reminderEnabled,
                reminderHour: hour,
                reminderMinute: minute,
                sortOrder: nextSortOrder()
            ))
        }

        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func nextSortOrder() -> Int {
        let existing = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        return (existing.map(\.sortOrder).max() ?? -1) + 1
    }
}

// MARK: - Input Type

private enum InputType: Equatable { case manual, timer, health }
