import SwiftUI

/// A few choices, three to a row, each drawn as a small picture of what it
/// does, so a layout shows itself instead of being named. Picked the way a
/// look is on `SwatchRail`: ringed with a gap and named in white. Sits in a
/// `Panel`.
struct SketchPicker<Item: Identifiable & Hashable, Sketch: View>: View {
    let items: [Item]
    @Binding var selection: Item
    let name: (Item) -> String
    @ViewBuilder let sketch: (Item) -> Sketch

    private let gap: CGFloat = 3
    private let spacing: CGFloat = 12

    var body: some View {
        // Plain rows, not a lazy grid: a lazy grid in a page whose card
        // preview measures itself never settled.
        let perRow = min(items.count, 3)
        let rows = stride(from: 0, to: items.count, by: perRow).map { Array(items[$0..<min($0 + perRow, items.count)]) }
        VStack(spacing: spacing) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(rows[index]) { cell($0) }
                    // Keeps a short last row's cells the size of the rest.
                    ForEach(0..<(perRow - rows[index].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
        .padding(AppLayout.tilePadding)
    }

    private func cell(_ item: Item) -> some View {
        let isSelected = item == selection
        let radius = AppLayout.wellRadius
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            selection = item
        } label: {
            VStack(spacing: 6) {
                sketch(item)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .padding(gap)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius + gap, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                    }
                Text(name(item))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .contentShape(.rect)
            .motion(AppMotion.snap, value: isSelected)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(name(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
