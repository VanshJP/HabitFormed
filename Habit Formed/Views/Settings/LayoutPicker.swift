import SwiftUI

/// Tiles or rows, each drawn as a small picture of Today in that layout, so
/// the choice shows what it does. Picked the way a look is on `SwatchRail`:
/// ringed with a gap and named in white.
struct LayoutPicker: View {
    @Binding var selection: TodayLayout

    private let gap: CGFloat = 3

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TodayLayout.allCases) { layout in
                cell(layout)
            }
        }
        .padding(AppLayout.tilePadding)
    }

    private func cell(_ layout: TodayLayout) -> some View {
        let isSelected = layout == selection
        let radius = AppLayout.wellRadius
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            selection = layout
        } label: {
            VStack(spacing: 6) {
                LayoutSketch(layout: layout)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .padding(gap)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius + gap, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                    }
                Text(layout.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .contentShape(.rect)
            .motion(AppMotion.snap, value: isSelected)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(layout.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Today in miniature: two filled squares among four, or one filled row among
/// three, since done is a habit filled with its color.
private struct LayoutSketch: View {
    let layout: TodayLayout

    var body: some View {
        switch layout {
        case .tiles:
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                GridRow { block(done: true); block(done: false) }
                GridRow { block(done: false); block(done: true) }
            }
            .aspectRatio(1, contentMode: .fit)
        case .rows:
            VStack(spacing: 5) {
                block(done: true)
                block(done: false)
                block(done: false)
            }
        }
    }

    private func block(done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(done ? AppColors.primary : Color.white.opacity(0.14))
    }
}
