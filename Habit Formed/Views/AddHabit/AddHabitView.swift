import SwiftUI
import SwiftData

/// Add or edit a habit. A new habit can start from a template in one tap;
/// every field lives in a `HabitDraft` that is written on Save.
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
    @FocusState private var nameFocused: Bool

    private var isDirty: Bool { draft != original }

    var body: some View {
        NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    if habit == nil {
                        HabitTemplateRail { template in
                            Haptics.selection()
                            withAnimation(AppMotion.settle) { draft.apply(template) }
                            nameFocused = false
                        }
                    }

                    nameCard
                    HabitAppearanceSection(draft: $draft)
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
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .interactiveDismissDisabled(isDirty)
            .onAppear(perform: load)
        }
    }

    // MARK: - Name

    private var nameCard: some View {
        GlassCard(tint: AppColors.identityTint(Color(hex: draft.colorHex))) {
            HStack(spacing: 14) {
                IconChip(icon: draft.symbol, tint: Color(hex: draft.colorHex), size: 44)
                    .motion(AppMotion.snap, value: draft.symbol)

                VStack(alignment: .leading, spacing: 6) {
                    TextField(
                        "",
                        text: $draft.title,
                        prompt: Text("Habit name").foregroundStyle(.white.opacity(0.4))
                    )
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .inputWell(isFocused: nameFocused)

                    Text(draft.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
        }
    }

    // MARK: - Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let habit {
            draft = HabitDraft(habit: habit)
        } else {
            nameFocused = true
        }
        original = draft
    }

    private func save() {
        guard draft.canSave, !isSaving else { return }
        isSaving = true
        Task {
            // Ask for Health over this sheet, before the habit exists: once
            // the sheet starts closing, the Health prompt has nowhere to show.
            if draft.kind == .health { try? await health.requestAuthorization() }
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
