import Photos
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The daily report: pick a template, see the card exactly as it will leave,
/// then text it, share it, save it or copy it. The card carries the name and
/// date, so a friend can forward it on and it still makes sense.
struct DailyReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var health

    @Query(sort: [SortDescriptor(\ReportTemplate.sortOrder), SortDescriptor(\ReportTemplate.createdAt)])
    private var templates: [ReportTemplate]

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.lastTemplateID) private var lastTemplateID = ""

    @State private var reportDay: Date
    @State private var kind: ShareKind = .card
    @State private var metrics: DayHealthMetrics = .empty
    @State private var eatenText = ""
    @State private var preview: UIImage?
    @State private var editing: ReportTemplate?
    @State private var showPresets = false
    @State private var pendingDelete: ReportTemplate?
    @State private var confirmation: String?
    @State private var didSeed = false
    @State private var askedHealth = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, eaten }

    init(day: Date) {
        _reportDay = State(initialValue: day.startOfDay)
    }

    // MARK: - Derived

    private var selected: ReportTemplate? {
        templates.first { $0.id.uuidString == lastTemplateID } ?? templates.first
    }

    /// Health with the typed calories laid over Apple Health's number.
    private var effectiveMetrics: DayHealthMetrics {
        var merged = metrics
        let digits = eatenText.filter { "0123456789.".contains($0) }
        if let typed = Double(digits) {
            merged.eatenKcal = min(typed, 99_999)
        }
        return merged
    }

    private func makeReport(for content: ReportContent) -> DailyReport {
        DailyReportBuilder.build(
            habits: habits,
            day: reportDay,
            content: content,
            name: reporterName,
            health: effectiveMetrics,
            liveValues: health.liveValues,
            liveWeeklyValues: health.liveWeeklyValues
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let template = selected {
                    composer(template)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background { AppBackground(style: .subtle) }
            .navigationTitle("Daily report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                if let template = selected {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            Haptics.light()
                            editing = template
                        }
                    }
                }
            }
            .navigationDestination(item: $editing) { template in
                ReportTemplateEditor(template: template, habits: habits) { content in
                    makeReport(for: content)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { AppBackground(style: .subtle) }
        .sheet(isPresented: $showPresets) {
            ReportPresetPicker { preset in addTemplate(from: preset) }
        }
        .alert(
            "Delete this template?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { template in
            Button("Delete", role: .destructive) { deleteTemplate(template) }
            Button("Cancel", role: .cancel) {}
        } message: { template in
            Text("This permanently deletes the \(template.name) template. Your habits are not touched.")
        }
        .task { seedIfNeeded() }
        .task(id: HealthKey(day: reportDay, needsHealth: selected?.content.needsHealth ?? false)) {
            await loadHealth()
        }
    }

    // MARK: - Composer

    private func composer(_ template: ReportTemplate) -> some View {
        let content = template.content
        let report = makeReport(for: content)
        let caption = ReportText.caption(report: report, content: content)

        return PageScrollView {
            VStack(alignment: .leading, spacing: AppLayout.listSpacing) {
                dayRow

                SectionPicker(
                    sections: ShareKind.allCases,
                    selection: $kind,
                    label: { $0.title },
                    icon: { $0.icon },
                    style: .compact
                )

                switch kind {
                case .card, .story:
                    cardPreview(caption: caption)
                    Text(kind == .story
                         ? "Full screen 9:16, sized for Instagram and Snapchat stories."
                         : "The card plus your message, ready for a group chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                case .text:
                    textPreview(caption)
                }

                templateStrip(selectedID: template.id)

                if reporterName.trimmingCharacters(in: .whitespaces).isEmpty {
                    namePrompt
                }

                if content.showCalories || content.style == .fuel {
                    caloriesCard
                }
            }
            .padding(.horizontal, AppLayout.pageHorizontal)
            .padding(.bottom, AppLayout.pageBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            actionRow(report: report, content: content, caption: caption)
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                ConfirmationToast(message: confirmation)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .motion(AppMotion.slide, value: confirmation)
        .task(id: RenderKey(report: report, content: content, kind: kind)) {
            // A short pause lets typing settle before the card re-renders.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            preview = kind == .story
                ? ReportCardRenderer.renderStory(report: report, content: content, scale: 1.5)
                : ReportCardRenderer.render(report: report, content: content, scale: 2)
        }
    }

    // MARK: - Day

    private var dayRow: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.selection()
                reportDay = reportDay.adding(days: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .headerIconChrome()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")

            VStack(spacing: 1) {
                Text(reportDay.relativeDayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(reportDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                Haptics.selection()
                reportDay = reportDay.adding(days: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .headerIconChrome()
            }
            .buttonStyle(.plain)
            .disabled(reportDay.isToday)
            .opacity(reportDay.isToday ? 0.35 : 1)
            .accessibilityLabel("Next day")
        }
    }

    // MARK: - Previews

    private func cardPreview(caption: String) -> some View {
        Group {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
                    .accessibilityLabel("Report card preview")
                    .accessibilityValue(caption)
            } else {
                RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
                    .fill(AppColors.surfaceLift)
                    .aspectRatio(0.62, contentMode: .fit)
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .onTapGesture {
            Haptics.light()
            editing = selected
        }
    }

    /// The text is the preview: every word shown is a word that leaves.
    private func textPreview(_ caption: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(caption)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                MetricRowDivider()
                Text("Change these words in Edit → Message. Tokens like {done} fill in each day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Templates

    private func templateStrip(selectedID: UUID) -> some View {
        GlassSection("Templates") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(templates) { template in
                        TemplateSwatch(template: template, isSelected: template.id == selectedID) {
                            guard template.id != selectedID else { return }
                            Haptics.selection()
                            lastTemplateID = template.id.uuidString
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "slider.horizontal.3") { editing = template }
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(template) }
                            Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = template }
                                .disabled(templates.count <= 1)
                        }
                    }

                    Button {
                        Haptics.light()
                        showPresets = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: TemplateSwatch.size.width, height: TemplateSwatch.size.height)
                                .controlChrome(in: RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                            Text("New")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(GlassPressStyle())
                    .accessibilityLabel("New template")
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
        } accessory: {
            Text("Long-press to edit")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Name and calories

    private var namePrompt: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Put your name on it")
                    .font(.subheadline.weight(.semibold))
                TextField("", text: $reporterName, prompt: Text("Your name").foregroundStyle(.white.opacity(0.4)))
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .name)
                    .inputWell(isFocused: focusedField == .name)
                Text("So a friend who forwards your card still knows whose day it was.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var caloriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calories eaten")
                            .font(.subheadline.weight(.semibold))
                        Text(metrics.eatenKcal == nil
                             ? "Not in Apple Health for this day. Type a total to include it."
                             : "From Apple Health. Type a number to override it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    TextField(
                        "",
                        text: $eatenText,
                        prompt: Text(metrics.eatenKcal.map { $0.safeRounded.formatted() } ?? "kcal")
                            .foregroundStyle(.white.opacity(0.4))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.statValue)
                    .frame(width: 86)
                    .focused($focusedField, equals: .eaten)
                    .inputWell(isFocused: focusedField == .eaten)
                }
                if let burned = metrics.burnedKcal {
                    Text("Burned \(burned.safeRounded.formatted()) kcal so far (active + resting).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func actionRow(report: DailyReport, content: ReportContent, caption: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            switch kind {
            case .card, .story:
                ShareAction(icon: "square.and.arrow.down", label: "Save") {
                    Task { await saveToPhotos(report: report, content: content) }
                }
                ShareAction(icon: "doc.on.doc", label: "Copy") {
                    copyCard(report: report, content: content, caption: caption)
                }
                if MessageComposer.canSend {
                    ShareAction(icon: "message.fill", label: "Text it") {
                        textCard(report: report, content: content, caption: caption)
                    }
                }
                ShareAction(icon: "square.and.arrow.up", label: "Share", prominent: true) {
                    shareCard(report: report, content: content, caption: caption)
                }
            case .text:
                ShareAction(icon: "doc.on.doc", label: "Copy") {
                    UIPasteboard.general.string = caption
                    Haptics.success()
                    confirm("Copied")
                }
                if MessageComposer.canSend {
                    ShareAction(icon: "message.fill", label: "Text it") {
                        Haptics.medium()
                        MessageComposer.shared.present(image: nil, body: caption)
                    }
                }
                ShareAction(icon: "square.and.arrow.up", label: "Share", prominent: true) {
                    Haptics.medium()
                    SharePresenter.present(items: [caption])
                }
            }
        }
        .padding(.horizontal, AppLayout.pageHorizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func fullImage(report: DailyReport, content: ReportContent) -> UIImage? {
        kind == .story
            ? ReportCardRenderer.renderStory(report: report, content: content, scale: 3)
            : ReportCardRenderer.render(report: report, content: content, scale: 3)
    }

    /// Stories go to apps that ignore a caption, so only the card sends one.
    private func message(_ caption: String, content: ReportContent) -> String? {
        kind == .card && content.attachCaption ? caption : nil
    }

    private func shareCard(report: DailyReport, content: ReportContent, caption: String) {
        guard let image = fullImage(report: report, content: content) else { return }
        Haptics.medium()
        SharePresenter.present(image: image, message: message(caption, content: content))
    }

    private func textCard(report: DailyReport, content: ReportContent, caption: String) {
        guard let image = fullImage(report: report, content: content) else { return }
        Haptics.medium()
        MessageComposer.shared.present(image: image, body: message(caption, content: content))
    }

    private func copyCard(report: DailyReport, content: ReportContent, caption: String) {
        guard let image = fullImage(report: report, content: content) else { return }
        let attach = message(caption, content: content) != nil
        Task {
            // PNG-encoding a 1170 px card takes tens of milliseconds, so it
            // stays off the main actor.
            let png = await Task.detached(priority: .userInitiated) { image.pngData() }.value
            var item: [String: Any] = [:]
            if let png { item[UTType.png.identifier] = png }
            if attach { item[UTType.utf8PlainText.identifier] = caption }
            UIPasteboard.general.setItems([item])
            Haptics.success()
            confirm("Copied")
        }
    }

    private func saveToPhotos(report: DailyReport, content: ReportContent) async {
        guard let image = fullImage(report: report, content: content) else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            confirm("Allow photo access in Settings to save")
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        Haptics.success()
        confirm("Saved to Photos")
    }

    private func confirm(_ text: String) {
        confirmation = text
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if confirmation == text { confirmation = nil }
        }
    }

    // MARK: - Template management

    /// The first time the sheet opens (or after every template was deleted)
    /// it fills in one template per preset, so there is always something to
    /// send.
    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        guard templates.isEmpty else { return }
        for (index, preset) in ReportPreset.all.enumerated() {
            modelContext.insert(ReportTemplate.make(from: preset, sortOrder: index))
        }
        try? modelContext.save()
    }

    private func addTemplate(from preset: ReportPreset) {
        let next = (templates.map(\.sortOrder).max() ?? -1) + 1
        let template = ReportTemplate.make(from: preset, sortOrder: next)
        modelContext.insert(template)
        try? modelContext.save()
        lastTemplateID = template.id.uuidString
        Haptics.success()
        // Push once the preset sheet has finished leaving.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            editing = template
        }
    }

    private func duplicate(_ template: ReportTemplate) {
        let next = (templates.map(\.sortOrder).max() ?? -1) + 1
        let copy = ReportTemplate(name: "\(template.name) copy", sortOrder: next)
        copy.copySettings(from: template)
        modelContext.insert(copy)
        try? modelContext.save()
        lastTemplateID = copy.id.uuidString
        Haptics.success()
    }

    private func deleteTemplate(_ template: ReportTemplate) {
        Haptics.warning()
        if lastTemplateID == template.id.uuidString { lastTemplateID = "" }
        modelContext.delete(template)
        try? modelContext.save()
        pendingDelete = nil
    }

    // MARK: - Health

    private func loadHealth() async {
        guard selected?.content.needsHealth == true else {
            metrics = .empty
            return
        }
        if !askedHealth {
            askedHealth = true
            await health.requestReportAuthorization()
        }
        metrics = await health.dayMetrics(for: reportDay)
    }
}

// MARK: - Keys

nonisolated private struct HealthKey: Equatable {
    let day: Date
    let needsHealth: Bool
}

nonisolated private struct RenderKey: Equatable {
    let report: DailyReport
    let content: ReportContent
    let kind: ShareKind
}

// MARK: - Share kind

nonisolated enum ShareKind: String, CaseIterable, Identifiable, Sendable {
    case card
    case story
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "Card"
        case .story: return "Story"
        case .text: return "Text"
        }
    }

    var icon: String {
        switch self {
        case .card: return "photo"
        case .story: return "rectangle.portrait"
        case .text: return "text.alignleft"
        }
    }
}

// MARK: - Template Swatch

/// A template in the strip: its canvas (or paper) with the style's glyph, and
/// its name.
private struct TemplateSwatch: View {
    let template: ReportTemplate
    let isSelected: Bool
    let action: () -> Void

    static let size = CGSize(width: 64, height: 84)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if template.style.isPaper {
                        Color(red: 0.984, green: 0.980, blue: 0.965)
                    } else {
                        CanvasLookView(look: template.theme.look, mood: .session)
                    }
                    Image(systemName: template.style.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(template.style.isPaper ? AppColors.inkOnLight : Color(hex: template.accentHex).glyphTone)
                }
                .frame(width: Self.size.width, height: Self.size.height)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.95) : AppColors.cardStroke, lineWidth: isSelected ? 2 : 1)
                }

                Text(template.name)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: Self.size.width + 8)
            }
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(template.name)
        .accessibilityHint(template.style.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Share Action

/// A round action under the preview; the prominent one is the solid white disc.
private struct ShareAction: View {
    let icon: String
    let label: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(prominent ? AppColors.inkOnLight : .white)
                    .frame(width: 56, height: 56)
                    .background {
                        Circle().fill(prominent ? AppColors.solidWhite : AppColors.wellFill)
                        Circle().strokeBorder(AppColors.cardStroke, lineWidth: prominent ? 0 : 1)
                    }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(label)
    }
}
