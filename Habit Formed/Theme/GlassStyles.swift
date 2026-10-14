import SwiftUI

// MARK: - Glass Card Modifier

/// iOS 26 Liquid Glass plate, tinted by Settings → App look unless a tint is
/// given. Sets `isOnGlass` so controls inside paint a plate instead of a
/// second pane of glass.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppLayout.cardRadius
    var tint: Color? = nil

    @Environment(\.glassAppearance) private var glassAppearance

    func body(content: Content) -> some View {
        let glass: Glass = {
            if let tint { return .regular.tint(tint) }
            return .regular.tint(glassAppearance.glassTint)
        }()
        content
            .environment(\.isOnGlass, true)
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
    }
}

// MARK: - Glass Background

/// Glass behind a surface that is not a card: a chip on the canvas, the
/// header capsule. Tinted by Settings → App look.
private struct GlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.glassAppearance) private var glassAppearance

    func body(content: Content) -> some View {
        content.glassEffect(
            .regular.tint(glassAppearance.glassTint),
            in: .rect(cornerRadius: cornerRadius)
        )
    }
}

// MARK: - Control Chrome

/// The face of a small control that can sit on the canvas or on a card:
/// tinted interactive glass on the canvas, the painted plate on a card.
/// Branches on an environment value, never on animated state.
private struct ControlChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    /// Colors the glass on the canvas (an idea's habit color); a plate on a
    /// card stays neutral.
    var tint: Color?

    @Environment(\.isOnGlass) private var isOnGlass
    @Environment(\.glassAppearance) private var glassAppearance

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOnGlass {
            content.plateChrome(in: shape)
        } else {
            content.glassEffect(
                .regular.tint(tint ?? glassAppearance.glassTint).interactive(),
                in: shape
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(cornerRadius: CGFloat = AppLayout.cardRadius, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Soft glass plate for a surface that is not a card.
    func glassBackground(cornerRadius: CGFloat = AppLayout.tileRadius) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }

    /// Round, interactive glass behind an icon-only control, such as the
    /// timer's close button.
    func glassCircle() -> some View {
        self.glassEffect(.regular.interactive(), in: .circle)
    }

    /// The painted face of a control on a glass plate: white 0.10 fill and a
    /// 0.16 rim. `isFocused` brightens the rim for a focused input.
    func plateChrome<S: InsettableShape>(in shape: S, isFocused: Bool = false) -> some View {
        self
            .background { shape.fill(Color.white.opacity(0.10)) }
            .overlay {
                shape.strokeBorder(Color.white.opacity(isFocused ? 0.4 : 0.16), lineWidth: 1)
            }
    }

    /// A small control's face wherever it sits: glass on the canvas, the plate
    /// on a card.
    func controlChrome<S: InsettableShape>(in shape: S, tint: Color? = nil) -> some View {
        modifier(ControlChrome(shape: shape, tint: tint))
    }

    /// A text field's well inside a card: the plate at the well radius, its
    /// rim brightening while the field has focus.
    func inputWell(isFocused: Bool = false) -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .plateChrome(
                in: RoundedRectangle(cornerRadius: AppLayout.wellRadius, style: .continuous),
                isFocused: isFocused
            )
    }
}

// MARK: - Glass Section Header

/// A page chapter's name. Text only, headline weight, with an optional
/// detail right after it ("2 of 6 done") and an optional trailing fact
/// (`HeaderMeta`) or door (`HeaderLinkLabel`). Flush with the cards under
/// it: text outside a card sits on the card's edge, text inside sits
/// `AppLayout.tilePadding` in.
struct GlassSectionHeader<Accessory: View>: View {
    let title: String
    var detail: String?
    var accessory: Accessory

    init(_ title: String, detail: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .motion(AppMotion.snap, value: detail)
                }
            }
            Spacer()
            accessory
        }
    }
}

extension GlassSectionHeader where Accessory == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

extension GlassSectionHeader where Accessory == HeaderMeta? {
    /// A header with a count or a date at its trailing end.
    init(_ title: String, meta: String?) {
        self.init(title) {
            meta.map { HeaderMeta($0) }
        }
    }
}

// MARK: - Header Accessories

/// A fact in a header's trailing slot: "3 logs", "This week".
struct HeaderMeta: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .motion(AppMotion.snap, value: text)
    }
}

/// A door in a header's trailing slot ("Share ›", "Edit ›"), in
/// `HeaderMeta`'s type so a link is not louder than the facts beside it.
struct HeaderLinkLabel: View {
    let title: String
    var icon: String = "chevron.right"

    init(_ title: String, icon: String = "chevron.right") {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(minHeight: AppLayout.minHitTarget)
        .contentShape(.rect)
    }
}

// MARK: - Glass Section

/// A section header and the content it introduces, `AppLayout.headerGap`
/// apart.
struct GlassSection<Accessory: View, Content: View>: View {
    let header: GlassSectionHeader<Accessory>
    let content: Content

    init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.header = GlassSectionHeader(title, detail: detail, accessory: accessory)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.headerGap) {
            header
            content
        }
    }
}

extension GlassSection where Accessory == HeaderMeta? {
    init(_ title: String, meta: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = GlassSectionHeader(title, meta: meta)
        self.content = content()
    }
}

// MARK: - Glass Card Title

/// Card-level title row, one register below `GlassSectionHeader`.
struct GlassCardTitle<Accessory: View>: View {
    let title: String
    let icon: String?
    var accessory: Accessory

    init(_ title: String, icon: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.icon = icon
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            accessory
        }
    }
}

extension GlassCardTitle where Accessory == EmptyView {
    init(_ title: String, icon: String? = nil) {
        self.init(title, icon: icon) { EmptyView() }
    }
}

// MARK: - Row Label Style

/// A settings row's name: its glyph in a fixed column, so every title on a
/// card starts on the same line whatever each symbol's width.
struct RowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: RowLayout.spacing) {
            configuration.icon
                .frame(width: RowLayout.glyphColumn)
            configuration.title
        }
    }
}

extension LabelStyle where Self == RowLabelStyle {
    static var row: RowLabelStyle { RowLabelStyle() }
}
