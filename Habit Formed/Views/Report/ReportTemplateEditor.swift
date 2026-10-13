import SwiftData
import SwiftUI
import UIKit

/// Everything about one report template: its layout, background and accent,
/// its words (with tokens that fill in each day), the text message, which
/// habits it covers, and the Apple Health numbers it shows. Changes save as
/// they are made; the preview at the top redraws as you type.
struct ReportTemplateEditor: View {
    @Bindable var template: ReportTemplate
    let habits: [Habit]
    let makeReport: (ReportContent) -> DailyReport

    @Environment(\.modelContext) private var modelContext

    @State private var preview: UIImage?
    @State private var lastWordField: WordField = .title
    @FocusState private var focused: WordField?

    private enum WordField: Hashable { case name, title, message, footer, caption, goal }

    private static let accentChoices: [Color] = AppColors.tilePalette + [
        AppColors.success, AppColors.warning, AppColors.error, Color.white,
    ]

    var body: some View {
        let content = template.content
        let report = makeReport(content)

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                previewBlock
                nameSection
                layoutSection
                lookSection
                wordsSection
                captionSection(report: report, content: content)
                habitsSection
                healthSection
            }
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.bottom, AppLayout.pageBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground(style: .subtle) }
        .navigationTitle("Edit template")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: EditorRenderKey(report: report, content: content)) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            preview = ReportCardRenderer.render(report: report, content: content, scale: 2)
        }
        .onChange(of: focused) { _, field in
            if let field, field != .name, field != .goal { lastWordField = field }
        }
        .onChange(of: template.includeAllHabits) { _, includeAll in
            // Turning "All habits" off starts from everything ticked, so the
            // card never goes blank mid-edit.
            if !includeAll && template.selectedHabitIDs.isEmpty {
                template.selectedHabitIDs = Set(habits.map(\.id))
            }
        }
        .onChange(of: template.calorieGoal) { _, goal in
            let clamped = goal.isFinite ? min(max(goal, 0), 99_999) : 2000
            if clamped != goal { template.calorieGoal = clamped }
        }
        .onDisappear { try? modelContext.save() }
    }

    // MARK: - Preview

    private var previewBlock: some View {
        Group {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            } else {
                RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                    .fill(AppColors.surfaceLift)
                    .aspectRatio(0.62, contentMode: .fit)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .frame(maxHeight: 380)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Live preview")
    }

    // MARK: - Name

    private var nameSection: some View {
        GlassSection("Template name") {
            TextField("", text: $template.name, prompt: Text("Only you see this").foregroundStyle(.white.opacity(0.4)))
                .submitLabel(.done)
                .focused($focused, equals: .name)
                .inputWell(isFocused: focused == .name)
        }
    }

    // MARK: - Layout

    private var layoutSection: some View {
        GlassSection("Layout") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ReportStyle.allCases) { style in
                        styleTile(style)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
        }
    }

    private func styleTile(_ style: ReportStyle) -> some View {
        let isSelected = template.style == style
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            template.style = style
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: style.symbol)
                    .font(.title3.weight(.semibold))
                Text(style.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(style.summary)
                    .font(.caption2)
                    .opacity(0.7)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? AppColors.inkOnLight : .white)
            .frame(width: 118, height: 108, alignment: .topLeading)
            .padding(12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
                        .fill(AppColors.solidWhite)
                }
            }
            .glassCardIf(!isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Look

    private var lookSection: some View {
        GlassSection(template.style.isPaper ? "Accent" : "Background and accent") {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    if !template.style.isPaper {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                            ForEach(ReportTheme.allCases) { theme in
                                themeSwatch(theme)
                            }
                        }
                        MetricRowDivider()
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                        ForEach(Self.accentChoices, id: \.hexString) { color in
                            accentButton(color)
                        }
                    }
                }
            }
        }
    }

    private func themeSwatch(_ theme: ReportTheme) -> some View {
        let isSelected = template.theme == theme
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            template.theme = theme
        } label: {
            VStack(spacing: 4) {
                CanvasLookView(look: theme.look, mood: .session)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.95) : AppColors.cardStroke, lineWidth: isSelected ? 2 : 1)
                    }
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func accentButton(_ color: Color) -> some View {
        let hex = color.hexString
        let isSelected = template.accentHex.uppercased() == hex.uppercased()
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            template.accentHex = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Color.white, lineWidth: 2.5).padding(-4)
                    }
                }
                .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accent \(hex)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Words

    private var wordsSection: some View {
        GlassSection("Words on the card") {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    wordField("Title", text: $template.title, prompt: "Daily report", field: .title)
                    wordField("Message", text: $template.message, prompt: "A promise, a dare, a quote", field: .message)
                    wordField("Footer", text: $template.footer, prompt: "Tracked with Habit Formed", field: .footer)
                    MetricRowDivider()
                    TokenBar(target: tokenTargetName, onInsert: insert)
                }
            }
        }
    }

    private func wordField(_ label: String, text: Binding<String>, prompt: String, field: WordField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .eyebrowStyle()
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.4)), axis: .vertical)
                .lineLimit(1...3)
                .focused($focused, equals: field)
                .inputWell(isFocused: focused == field)
        }
    }

    // MARK: - Caption

    private func captionSection(report: DailyReport, content: ReportContent) -> some View {
        GlassSection("Text message") {
            VStack(alignment: .leading, spacing: 10) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(
                            "",
                            text: $template.caption,
                            prompt: Text(ReportText.defaultCaption).foregroundStyle(.white.opacity(0.4)),
                            axis: .vertical
                        )
                        .lineLimit(3...10)
                        .focused($focused, equals: .caption)
                        .inputWell(isFocused: focused == .caption)

                        TokenBar(target: tokenTargetName, onInsert: insert)

                        if !template.caption.isEmpty {
                            Button("Use the standard message") {
                                Haptics.light()
                                template.caption = ""
                            }
                            .font(.footnote.weight(.medium))
                            .frame(minHeight: AppLayout.minHitTarget)
                            .buttonStyle(.textLink)
                        }
                    }
                }

                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    SettingsRow(
                        "Send it with the card",
                        icon: "text.bubble",
                        caption: "Off sends the image alone.",
                        isOn: $template.attachCaption
                    )
                }

                Text("Sends as: \(ReportText.caption(report: report, content: content))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Tokens

    private var tokenTargetName: String {
        switch lastWordField {
        case .title: return "title"
        case .message: return "message"
        case .footer: return "footer"
        case .caption: return "text message"
        case .name, .goal: return "title"
        }
    }

    private func insert(_ token: ReportToken) {
        Haptics.selection()
        switch lastWordField {
        case .title, .name, .goal: template.title = appending(token, to: template.title)
        case .message: template.message = appending(token, to: template.message)
        case .footer: template.footer = appending(token, to: template.footer)
        case .caption: template.caption = appending(token, to: template.caption)
        }
    }

    private func appending(_ token: ReportToken, to text: String) -> String {
        guard !text.isEmpty else { return token.placeholder }
        if text.hasSuffix(" ") || text.hasSuffix("\n") { return text + token.placeholder }
        return text + " " + token.placeholder
    }

    // MARK: - Habits

    private var habitsSection: some View {
        GlassSection("Habits") {
            VStack(alignment: .leading, spacing: 12) {
                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    SettingsRow("All habits", icon: "square.grid.2x2", caption: "Off lets you pick which ones this card covers.", isOn: $template.includeAllHabits)
                    if !template.includeAllHabits {
                        ForEach(habits) { habit in
                            habitRow(habit)
                        }
                    }
                }

                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    SettingsRow("Show unfinished habits", icon: "circle.dashed", caption: "Off shows wins only.", isOn: $template.showUnfinished)
                    SettingsRow("Streaks", icon: "flame", caption: "Each habit's run beside its name.", isOn: $template.showStreaks)
                    SettingsRow("Perfect-day streak", icon: "trophy", caption: "Days in a row with everything done.", isOn: $template.showPerfectStreak)
                    SettingsRow("Last 7 days", icon: "circle.grid.3x3", caption: "A row of dots for each habit's week.", isOn: $template.showWeek)
                    SettingsRow("Notes", icon: "text.quote", caption: "What you wrote on each log.", isOn: $template.showNotes)
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let isOn = template.selectedHabitIDs.contains(habit.id)
        return Button {
            Haptics.selection()
            var ids = template.selectedHabitIDs
            if isOn { ids.remove(habit.id) } else { ids.insert(habit.id) }
            template.selectedHabitIDs = ids
        } label: {
            ListRowLabel(icon: habit.symbol, tint: habit.color, title: habit.title, subtitle: habit.scheduleLabel, trailing: .none) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(habit.color.glyphTone) : AnyShapeStyle(.tertiary))
            }
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Health

    private var healthSection: some View {
        GlassSection("Apple Health") {
            VStack(alignment: .leading, spacing: 10) {
                GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                    SettingsRow("Calories in vs out", icon: "fork.knife", caption: "Eaten, burned and the net.", isOn: $template.showCalories)
                    if template.showCalories || template.style == .fuel {
                        SettingsRow("Daily budget", icon: "target", caption: "Zero hides the budget line.") {
                            HStack(spacing: 4) {
                                TextField("Calories", value: $template.calorieGoal, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .focused($focused, equals: .goal)
                                    .frame(width: 70)
                                Text("kcal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    SettingsRow("Activity", icon: "figure.walk", caption: "Steps, exercise, sleep and mindful minutes.", isOn: $template.showActivity)
                }

                Text("Numbers come from Apple Health. Food trackers that sync to Health fill in calories eaten, and you can type a number before sending.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Token Bar

/// Placeholders as chips. A tap adds one to the field you were last typing in.
private struct TokenBar: View {
    let target: String
    let onInsert: (ReportToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap to add to the \(target)")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(ReportToken.all) { token in
                    Button {
                        onInsert(token)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "curlybraces")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(token.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .plateChrome(in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(GlassPressStyle())
                    .accessibilityLabel("Insert \(token.label)")
                }
            }
        }
    }
}

// MARK: - Helpers

private nonisolated struct EditorRenderKey: Equatable {
    let report: DailyReport
    let content: ReportContent
}

private extension View {
    /// Glass for an unselected tile; the selected one paints solid white,
    /// and glass is never animated on or off.
    @ViewBuilder
    func glassCardIf(_ condition: Bool) -> some View {
        if condition {
            glassCard(cornerRadius: AppLayout.tileRadius)
        } else {
            self
        }
    }
}

// MARK: - Preset Picker

/// The presets, for a new template. Every word, colour and section can be
/// changed after.
struct ReportPresetPicker: View {
    let onPick: (ReportPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.listSpacing) {
                    Text("Start from a preset. You can change every word, colour and section after.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    GlassRowGroup(dividerInset: RowLayout.dividerInset) {
                        ForEach(ReportPreset.all) { preset in
                            Button {
                                dismiss()
                                onPick(preset)
                            } label: {
                                ListRowLabel(
                                    icon: preset.style.symbol,
                                    tint: preset.style.isPaper ? .white : Color(hex: preset.accentHex),
                                    title: preset.name,
                                    subtitle: preset.blurb
                                )
                            }
                            .buttonStyle(RowPressStyle())
                        }
                    }
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .background { AppBackground(style: .subtle) }
            .navigationTitle("New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
