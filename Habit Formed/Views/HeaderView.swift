import SwiftUI

/// Top-of-screen header — date, day-of-week, and a small completion summary
/// for the selected date. Tap the date to browse past days; the "Today" pill
/// appears whenever the user has scrolled away from today.
struct HeaderView: View {
    @Binding var selectedDate: Date
    let isViewingToday: Bool
    let completedCount: Int
    let totalHabits: Int
    let onResetToToday: () -> Void
    var onAdd: () -> Void = {}

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(topLabel)
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add habit")
            }

            HStack(alignment: .firstTextBaseline) {
                Button {
                    Haptics.light()
                    showPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse date")
                .accessibilityHint("Opens a date picker")

                Spacer()

                if !isViewingToday {
                    Button {
                        Haptics.selection()
                        onResetToToday()
                    } label: {
                        Text("Today")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AppColors.primary.opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else if totalHabits > 0 {
                    Text("\(completedCount) / \(totalHabits)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isViewingToday)
        }
        .sheet(isPresented: $showPicker) {
            DateBrowserSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var topLabel: String {
        if selectedDate.isToday { return "TODAY" }
        if selectedDate.isYesterday { return "YESTERDAY" }
        return selectedDate.formatted(.dateTime.weekday(.wide)).uppercased()
    }
}

private struct DateBrowserSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(style: .primary).ignoresSafeArea()
                DatePicker(
                    "Browse date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.primary)
                .padding(.horizontal, 16)
            }
            .navigationTitle("Browse Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
