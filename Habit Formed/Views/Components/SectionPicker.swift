import SwiftUI

/// The one segmented selector (track type, schedule, report kind), ported from
/// SpeakUp so a selected segment is the same solid white pill everywhere.
struct SectionPicker<Section: Hashable & Identifiable>: View {
    enum Style { case regular, compact }
    enum Layout { case equalWidth, scrollable }

    let sections: [Section]
    @Binding var selection: Section
    let label: (Section) -> String
    let icon: (Section) -> String?
    var style: Style = .regular
    var layout: Layout = .equalWidth
    var framed: Bool = true

    @Namespace private var pickerNamespace
    @Environment(\.glassAppearance) private var glassAppearance

    init(
        sections: [Section],
        selection: Binding<Section>,
        label: @escaping (Section) -> String,
        icon: @escaping (Section) -> String? = { _ in nil },
        style: Style = .regular,
        layout: Layout = .equalWidth,
        framed: Bool = true
    ) {
        self.sections = sections
        self._selection = selection
        self.label = label
        self.icon = icon
        self.style = style
        self.layout = layout
        self.framed = framed
    }

    var body: some View {
        Group {
            switch layout {
            case .equalWidth:
                row
            case .scrollable:
                ScrollView(.horizontal) { row }
                    .scrollIndicators(.hidden)
            }
        }
        .background {
            if framed {
                Color.clear
                    .glassEffect(
                        .regular.tint(glassAppearance.glassTint),
                        in: .rect(cornerRadius: AppLayout.cardRadius)
                    )
            }
        }
        .shadow(color: framed ? .black.opacity(0.22) : .clear, radius: framed ? 14 : 0, y: framed ? 7 : 0)
    }

    @ViewBuilder
    private var row: some View {
        // 4 + 36 + 4: the framed picker lands on the 44pt hit target.
        switch layout {
        case .equalWidth:
            EqualWidthRow(spacing: itemSpacing) { items }
                .padding(framed ? 4 : 0)
        case .scrollable:
            HStack(spacing: itemSpacing) { items }
                .padding(framed ? 4 : 0)
        }
    }

    private var items: some View {
        ForEach(sections) { section in
            item(for: section)
        }
    }

    @ViewBuilder
    private func item(for section: Section) -> some View {
        let isSelected = selection == section
        Button {
            guard selection != section else { return }
            Haptics.selection()
            withAnimation(AppMotion.slide) {
                selection = section
            }
        } label: {
            HStack(spacing: iconLabelSpacing) {
                if let symbol = icon(section) {
                    Image(systemName: symbol)
                        .font(iconFont)
                }
                Text(label(section))
                    .font(labelFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? AppColors.inkOnLight : Color.white.opacity(0.55))
            .frame(maxWidth: layout == .equalWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .fill(AppColors.solidWhite)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "sectionPickerSelection", in: pickerNamespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    // MARK: - Style values

    private var itemSpacing: CGFloat { style == .regular ? 6 : 4 }
    private var iconLabelSpacing: CGFloat { style == .regular ? 6 : 4 }
    /// Equal-width segments fill their share, so they need no padding of
    /// their own; padding would push six chart tabs onto the rail.
    private var horizontalPadding: CGFloat {
        switch (style, layout) {
        case (_, .equalWidth): return 0
        case (.regular, .scrollable): return 14
        case (.compact, .scrollable): return 12
        }
    }
    private var verticalPadding: CGFloat { style == .regular ? 8 : 6 }
    /// Regular sits concentric in the frame: its radius less the 4pt inset.
    private var pillCornerRadius: CGFloat { style == .regular ? AppLayout.tileRadius : AppLayout.wellRadius }
    private var iconFont: Font { style == .regular ? .footnote.weight(.semibold) : .caption2.weight(.semibold) }
    private var labelFont: Font { style == .regular ? .subheadline.weight(.semibold) : .caption.weight(.semibold) }
}

// MARK: - Equal Width Row

/// Segments at one width. Its ideal width is the widest segment times the
/// count, not the sum of the segments, so a `ViewThatFits` drops to the
/// scrolling rail when the longest label would not fit its equal share. An
/// `HStack` of `maxWidth: .infinity` segments measures the sum and truncates.
private struct EqualWidthRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let count = CGFloat(subviews.count)
        let gaps = spacing * (count - 1)
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width: CGFloat
        if let proposed = proposal.width, proposed.isFinite {
            width = proposed
        } else {
            width = widest * count + gaps
        }
        let cell = ProposedViewSize(width: max(0, (width - gaps) / count), height: proposal.height)
        let height = subviews.map { $0.sizeThatFits(cell).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let count = CGFloat(subviews.count)
        let cellWidth = max(0, (bounds.width - spacing * (count - 1)) / count)
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: cellWidth, height: bounds.height)
            )
            x += cellWidth + spacing
        }
    }
}
