import SwiftUI
import SwiftData

/// Add or edit a habit, as a few plain questions: the name (with its icon
/// and color folded away), how you log it, how often, and a reminder. A new
/// habit can start from an idea in one tap. Every field lives in a
/// `HabitDraft` that is written on Save.
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
    @FocusState private var nameFocused: Bool

    private var isDirty: Bool { draft != original }

    var body: some View {
        NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    if habit == nil {
                        HabitIdeas(pickedTitle: draft.title) { template in
                            withAnimation(AppMotion.settle) { draft.apply(template) }
                            nameFocused = false
                        }
                    }

                    nameCard
                    HabitTrackSection(draft: $draft)
                    HabitScheduleSection(draft: $draft)
                    HabitReminderSection(draft: $draft)
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground(style: .subtle) }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.light()
                        if isDirty { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!draft.canSave)
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
                    prompt: Text("What's the habit?").foregroundStyle(.white.opacity(0.4))
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .focused($nameFocused)
                .submitLabel(.done)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Button(action: toggleLook) {
                HStack {
                    Text("Icon and color")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showLook ? 180 : 0))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
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
        // A new habit opens with the keyboard down, so the templates and the
        // whole form show; tapping the name brings it up.
        if let habit {
            draft = HabitDraft(habit: habit)
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
