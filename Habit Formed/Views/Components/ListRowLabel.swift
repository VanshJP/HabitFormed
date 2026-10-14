import SwiftUI

// MARK: - Row Layout

/// The measurements every row on a `GlassRowGroup` shares, so every title
/// starts on one line whatever its glyph.
nonisolated enum RowLayout {
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 12
    /// The column a row's bare lead glyph (`RowGlyph`) sits in.
    static let glyphColumn: CGFloat = 24
    /// Glyph to text.
    static let spacing: CGFloat = 12
    /// Where the group's hairlines start: under the text, not the glyph.
    static let dividerInset: CGFloat = horizontalPadding + glyphColumn + spacing
}

/// What closes a row on the trailing edge.
nonisolated enum RowTrailing {
    /// It pushes a page or opens a sheet.
    case chevron
    case none
}

// MARK: - List Row Label

/// A row's face: identity glyph, title, an optional subtitle and meta line, an
/// optional accessory, and a chevron. It draws no surface; put it in a
/// `Button` pressed with `RowPressStyle`, on a
/// `GlassRowGroup(dividerInset: RowLayout.dividerInset)`.
struct ListRowLabel<Accessory: View>: View {
    let icon: String
    var tint: Color
    let title: String
    var subtitle: String?
    var meta: String?
    var trailing: RowTrailing
    let accessory: Accessory

    init(
        icon: String,
        tint: Color = AppColors.primary,
        title: String,
        subtitle: String? = nil,
        meta: String? = nil,
        trailing: RowTrailing = .chevron,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.trailing = trailing
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: RowLayout.spacing) {
            RowGlyph(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let meta {
                    Text(meta)
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            accessory

            if trailing == .chevron {
                ListRowChevron()
            }
        }
        .padding(.horizontal, RowLayout.horizontalPadding)
        .padding(.vertical, RowLayout.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension ListRowLabel where Accessory == EmptyView {
    init(
        icon: String,
        tint: Color = AppColors.primary,
        title: String,
        subtitle: String? = nil,
        meta: String? = nil,
        trailing: RowTrailing = .chevron
    ) {
        self.init(
            icon: icon,
            tint: tint,
            title: title,
            subtitle: subtitle,
            meta: meta,
            trailing: trailing
        ) { EmptyView() }
    }
}

// MARK: - Chevron

/// The trailing mark of a row that opens something.
struct ListRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Glyphs

/// A hero glyph with no words beside it: the icon in its tint lifted towards
/// white, filling its frame. Bare, never on a disc or plate: a glyph on a
/// filled circle reads as generated decoration.
struct IconChip: View {
    let icon: String
    var tint: Color = AppColors.primary
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.62, weight: .medium))
            .foregroundStyle(tint.glyphTone)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A glyph beside the words it names: bare, lifted a third toward white, in
/// the row's `RowLayout.glyphColumn`.
struct RowGlyph: View {
    let icon: String
    var tint: Color = AppColors.primary

    var body: some View {
        Image(systemName: icon)
            .font(.body.weight(.medium))
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .foregroundStyle(tint.glyphTone)
            .frame(width: RowLayout.glyphColumn)
            .accessibilityHidden(true)
    }
}

/// A glyph inline with a card's title: the title's font in an 18pt box.
struct TitleGlyph: View {
    let icon: String
    var tint: Color = AppColors.primary
    @ScaledMetric(relativeTo: .subheadline) private var box: CGFloat = 18

    var body: some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint.glyphTone)
            .frame(width: box, height: box)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassRowGroup(dividerInset: RowLayout.dividerInset) {
            Button {} label: {
                ListRowLabel(icon: "book.fill", title: "Read", subtitle: "Daily", meta: "12 day streak")
            }
            Button {} label: {
                ListRowLabel(icon: "figure.walk", tint: AppColors.info, title: "Steps", subtitle: "10k a day")
            }
        }
        .buttonStyle(RowPressStyle())
    }
    .padding()
    .background(AppBackground())
}
