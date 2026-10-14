import SwiftUI

/// A small state capsule: "Logged", "Due today", "3 / 5 this week". Text and
/// an optional dot or icon, on a faint fill of its colour.
struct StatusPill: View {
    enum Glyph: Equatable {
        case none
        case dot
        case icon(String)
    }

    let text: String
    let color: Color
    var glyph: Glyph = .none
    var fillOpacity: Double = 0.12
    /// Text in a neutral colour, the tint kept to the glyph and fill, for a
    /// tint too dim to read at caption size.
    var textColor: Color?

    var body: some View {
        HStack(spacing: 4) {
            switch glyph {
            case .none:
                EmptyView()
            case .dot:
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            case .icon(let name):
                Image(systemName: name)
                    .font(.caption2.weight(.bold))
                    .imageScale(.small)
            }

            Text(text)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(textColor ?? color)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minHeight: 28)
        .background(Capsule().fill(color.opacity(fillOpacity)))
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusPill(text: "Logged", color: AppColors.success, glyph: .icon("checkmark"))
        StatusPill(text: "Due today", color: AppColors.warning, glyph: .dot)
        StatusPill(text: "Every 3 days", color: .white, textColor: .secondary)
    }
    .padding(40)
    .background(AppBackground())
}
