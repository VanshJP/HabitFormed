import SwiftUI

/// A row of looks to pick one from: the app's canvas, a report card's theme.
/// Flat swatches; the picked one is ringed with a gap and named in white.
/// The rail runs past the page edge so it reads as one that scrolls.
struct SwatchRail<Item: Identifiable & Hashable, Swatch: View>: View {
    let items: [Item]
    @Binding var selection: Item
    let name: (Item) -> String
    @ViewBuilder let swatch: (Item) -> Swatch

    private let size: CGFloat = 56
    private let gap: CGFloat = 3

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(items) { item in
                    cell(item)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, AppLayout.pageHorizontal - gap, for: .scrollContent)
        .padding(.horizontal, -AppLayout.pageHorizontal)
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
                swatch(item)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .padding(gap)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius + gap, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                    }
                Text(name(item))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .motion(AppMotion.snap, value: isSelected)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(name(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
