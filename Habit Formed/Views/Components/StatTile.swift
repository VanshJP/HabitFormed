import SwiftUI

/// One number in a grid of them: a glyph in its tint over a `StatPair`.
///
/// Inside a card it paints a static well (no glass on glass); on the canvas it
/// is a glass tile.
struct StatTile: View {
    var icon: String? = nil
    let value: String
    let label: String
    var tint: Color = AppColors.primary
    var alignment: HorizontalAlignment = .center

    @Environment(\.isOnGlass) private var isOnGlass

    private var frameAlignment: Alignment {
        alignment == .leading ? .leading : .center
    }

    var body: some View {
        if isOnGlass {
            tile
                .padding(AppLayout.tilePadding)
                .background(
                    AppColors.wellFill,
                    in: .rect(cornerRadius: AppLayout.wellRadius, style: .continuous)
                )
                .accessibilityElement(children: .combine)
        } else {
            GlassCard(cornerRadius: AppLayout.tileRadius, padding: AppLayout.tilePadding) {
                tile
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var tile: some View {
        VStack(alignment: alignment, spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            StatPair(value: value, label: label, valueFont: .metricValue, alignment: alignment)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            StatTile(icon: "checkmark.circle.fill", value: "24", label: "Logs")
            StatTile(icon: "clock.fill", value: "96", label: "Minutes", tint: AppColors.info)
        }

        GlassCard {
            HStack(spacing: 12) {
                StatTile(icon: "flame.fill", value: "3", label: "Active", alignment: .leading)
                StatTile(icon: "checkmark.seal.fill", value: "7", label: "Done", tint: AppColors.success, alignment: .leading)
                StatTile(value: "142", label: "Total", alignment: .leading)
            }
        }
    }
    .padding()
    .background(AppBackground())
}
