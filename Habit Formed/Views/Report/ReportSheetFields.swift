import SwiftUI

/// Amounts typed over Apple Health's for one card: calories eaten and the
/// macros. Kept as text while typed, read as numbers when the card is built.
struct ReportTypedAmounts {
    var eaten = ""
    var protein = ""
    var carbs = ""
    var fat = ""

    /// Apple Health's numbers with whatever was typed laid over them.
    func applied(to health: DayHealthMetrics) -> DayHealthMetrics {
        var merged = health
        if let typed = Self.amount(eaten, cap: 99_999) { merged.eatenKcal = typed }
        if let typed = Self.amount(protein, cap: 9_999) { merged.protein = typed }
        if let typed = Self.amount(carbs, cap: 9_999) { merged.carbs = typed }
        if let typed = Self.amount(fat, cap: 9_999) { merged.fat = typed }
        return merged
    }

    /// A typed amount, digits only, capped so the card's columns hold it.
    private static func amount(_ text: String, cap: Double) -> Double? {
        let digits = text.filter { "0123456789.".contains($0) }
        return Double(digits).map { min($0, cap) }
    }
}

/// What you type onto the card being sent, in one panel under it: calories
/// eaten and the macros while they are on (the day's card only), and the
/// note. Your name is the studio's, kept for every card.
struct ReportSheetFields: View {
    let scope: ReportScope
    let picked: Set<ReportMetric>
    /// Apple Health's numbers, shown as each field's prompt.
    let health: DayHealthMetrics
    @Binding var note: String
    @Binding var typed: ReportTypedAmounts

    var body: some View {
        Panel {
            if scope == .day, picked.contains(.calories) {
                SettingsRow("Calories eaten", icon: ReportMetric.calories.icon) {
                    TextField(
                        "",
                        text: $typed.eaten,
                        prompt: Text(health.eatenKcal.map { $0.safeRounded.formatted() } ?? "kcal")
                            .foregroundStyle(.white.opacity(0.4))
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 90)
                }
            }
            if scope == .day, picked.contains(.macros) {
                MacroFieldsRow(protein: $typed.protein, carbs: $typed.carbs, fat: $typed.fat, health: health)
            }
            ReportNoteField(note: $note)
        }
        .motion(AppMotion.settle, value: picked)
    }
}

/// The note row: a line for this card only.
struct ReportNoteField: View {
    @Binding var note: String

    var body: some View {
        HStack(spacing: RowLayout.spacing) {
            RowGlyph(icon: "square.and.pencil", tint: .secondary)
            TextField(
                "",
                text: $note,
                prompt: Text("Add a note to this card").foregroundStyle(.white.opacity(0.4)),
                axis: .vertical
            )
            .font(.subheadline)
            .lineLimit(1...3)
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
        .frame(minHeight: AppLayout.minHitTarget)
    }
}
