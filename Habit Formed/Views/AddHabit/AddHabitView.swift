import SwiftUI
import SwiftData

/// Add or edit a habit, as a few plain questions: the name (with its icon
/// and color folded away), how you log it, how often, and a reminder. A new
/// habit opens on its name, with ideas under it that fill everything in one
/// tap. Close is the X; the one solid button, pinned at the bottom, adds or
/// saves. Every field lives in a `HabitDraft` that is written on save.
struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var health

    var habit: Habit?

    @State private var draft = HabitDraft()
    @State private var original = HabitDraft()
    @State private var didLoad = false
    @State private var confirmDiscard = false
    @State private var isSaving = false
    @State private var showLook = false
    /// Other habits' usual log times, for a new habit's suggested reminder.
    @State private var routine: [(title: String, minute: Int)]?
    @FocusState private var nameFocused: Bool

    private var isDirty: Bool { draft != original }

    var body: some View {
        NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    nameCard
                    if habit == nil {
                        HabitIdeas(pickedTitle: draft.title) { template in
                            withAnimation(AppMotion.settle) { draft.apply(template) }
                            nameFocused = false
                        }
                    }
                    HabitTrackSection(draft: $draft)
                    HabitScheduleSection(draft: $draft)
                    HabitReminderSection(draft: $draft, routine: routine)
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .safeAreaBar(edge: .bottom) {
                GlassButton(title: habit == nil ? "Add habit" : "Save changes", style: .primary, size: .large, fullWidth: true, action: save)
                    .disabled(!draft.canSave)
                    .padding(.horizontal, AppLayout.pageHorizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.light()
                        if isDirty { confirmDiscard = true } else { dismiss() }
                    }
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .interactiveDismissDisabled(isDirty)
            .onAppear(perform: load)
        }
    }

    // MARK: - Name

    /// The name beside its glyph, and under it the icon and color, folded
    /// away until asked for (the glyph opens them too).
    private var nameCard: some View {
        Panel {
            HStack(spacing: 14) {
                Button(action: toggleLook) {
                    IconChip(icon: draft.symbol, tint: Color(hex: draft.colorHex), size: 36)
                        .motion(AppMotion.snap, value: draft.symbol)
                        .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icon and color")

                TextField(
                    "",
                    text: $draft.title,
                    prompt: Text("Habit name").foregroundStyle(.white.opacity(0.4))
                )
                .font(.headline)
                .foregroundStyle(.white)
                .focused($nameFocused)
                .submitLabel(.done)
                .inputWell(isFocused: nameFocused)
            }
            // The glyph's 44pt hit area overhangs it by 4, so its box starts
            // on the card's inner line like the rows below.
            .padding(.leading, AppLayout.tilePadding - 4)
            .padding(.trailing, AppLayout.tilePadding)
            .padding(.vertical, 10)

            Button(action: toggleLook) {
                HStack {
                    Text("Icon and color")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(showLook ? 180 : 0))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppLayout.tilePadding)
                .frame(minHeight: AppLayout.minHitTarget)
                .contentShape(.rect)
            }
            .buttonStyle(RowPressStyle())
            .accessibilityLabel(showLook ? "Hide icon and color" : "Show icon and color")

            if showLook {
                HabitLookPicker(draft: $draft)
            }
        }
    }

    private func toggleLook() {
        Haptics.light()
        withAnimation(AppMotion.settle) { showLook.toggle() }
    }

    // MARK: - Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let habit {
            draft = HabitDraft(habit: habit)
        } else {
            let existing = (try? modelContext.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
            draft.colorHex = HabitDraft.freshColor(after: existing.map(\.colorHex))
            routine = existing.compactMap { other in other.usualLogMinute.map { (other.title, $0) } }
            // The name is the one thing a new habit needs; the ideas sit
            // right under it, above the keyboard.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                nameFocused = true
            }
        }
        original = draft
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        isSaving = true
        Task {
            // Ask for Health over this sheet, before the habit exists: once
            // the sheet starts closing, the Health prompt has nowhere to show.
            if draft.kind == .health { try? await health.requestAuthorization(for: [draft.source]) }
            if let habit {
                draft.apply(to: habit)
            } else {
                modelContext.insert(draft.makeHabit(sortOrder: nextSortOrder()))
            }
            try? modelContext.save()
            Haptics.success()
            dismiss()
        }
    }

    private func nextSortOrder() -> Int {
        let existing = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        return (existing.map(\.sortOrder).max() ?? -1) + 1
    }
}
