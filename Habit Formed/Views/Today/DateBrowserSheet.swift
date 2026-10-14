import SwiftUI

/// A calendar for reaching days older than the week strip shows.
struct DateBrowserSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Browse date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColors.brandBright)
            .padding(.horizontal, AppLayout.pageHorizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .background { AppBackground(style: .subtle) }
            .navigationTitle("Browse a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        Haptics.selection()
                        selectedDate = .now
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedDate) { _, _ in Haptics.selection() }
        }
    }
}
