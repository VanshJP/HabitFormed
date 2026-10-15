import SwiftUI

/// Protein, carbs and fat for the card, typed over what Apple Health has.
/// One row of three wells, each named above its number as the card prints
/// it, shown while Macros is on.
struct MacroFieldsRow: View {
    @Binding var protein: String
    @Binding var carbs: String
    @Binding var fat: String
    /// The day's grams from Apple Health, shown as each field's prompt.
    let health: DayHealthMetrics

    private enum Macro { case protein, carbs, fat }

    @FocusState private var focused: Macro?

    var body: some View {
        HStack(spacing: RowLayout.spacing) {
            RowGlyph(icon: ReportMetric.macros.icon, tint: .secondary)
            HStack(spacing: 8) {
                field("Protein", text: $protein, grams: health.protein, color: AppColors.macroProtein, macro: .protein)
                field("Carbs", text: $carbs, grams: health.carbs, color: AppColors.macroCarbs, macro: .carbs)
                field("Fat", text: $fat, grams: health.fat, color: AppColors.macroFat, macro: .fat)
            }
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
    }

    private func field(_ label: String, text: Binding<String>, grams: Double?, color: Color, macro: Macro) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color.glyphTone)
                    .frame(width: 6, height: 6)
                Text(label)
                    .eyebrowStyle()
            }
            .accessibilityHidden(true)
            TextField(
                "",
                text: text,
                prompt: Text(grams.map { "\($0.safeRounded)" } ?? "g")
                    .foregroundStyle(.white.opacity(0.4))
            )
            .keyboardType(.numberPad)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .focused($focused, equals: macro)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .plateChrome(
                in: RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous),
                isFocused: focused == macro
            )
            .accessibilityLabel("\(label) in grams")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
