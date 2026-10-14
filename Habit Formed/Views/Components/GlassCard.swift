import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    var tint: Color?
    var padding: CGFloat
    var accentBorder: Color?
    var elevated: Bool

    @Environment(\.glassAppearance) private var glassAppearance
    @Environment(\.isOnGlass) private var isOnGlass

    /// Defaults are a full-width card. A tile or half-width card passes
    /// `AppLayout.tileRadius` and `AppLayout.tilePadding`.
    init(
        cornerRadius: CGFloat = AppLayout.cardRadius,
        tint: Color? = nil,
        padding: CGFloat = AppLayout.cardPadding,
        accentBorder: Color? = nil,
        elevated: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.padding = padding
        self.accentBorder = accentBorder
        self.elevated = elevated
    }

    var body: some View {
        plate(
            content
                .environment(\.isOnGlass, true)
                .padding(padding)
        )
        .overlay {
            if let accentBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accentBorder.opacity(0.35), lineWidth: 1)
            }
        }
    }

    /// Glass on the canvas. Already on glass (another card) a second pane
    /// would sample the first and turn murky grey, so the card paints a flat
    /// panel instead.
    @ViewBuilder
    private func plate(_ padded: some View) -> some View {
        if isOnGlass {
            padded
                .background(tint ?? Color.white.opacity(0.05), in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                }
        } else {
            padded
                .glassEffect(resolvedGlass, in: .rect(cornerRadius: cornerRadius))
                .shadow(
                    color: .black.opacity(elevated ? 0.35 : 0.18),
                    radius: elevated ? 18 : 10,
                    y: elevated ? 9 : 5
                )
        }
    }

    private var resolvedGlass: Glass {
        if let tint {
            return .regular.tint(tint)
        }
        return .regular.tint(glassAppearance.glassTint)
    }
}

// MARK: - Glass Row Group

/// Rows that belong together on one plate, split by inset hairlines - the
/// grouped-list shape of iOS Settings.
///
/// Rows pad themselves. The group draws the plate, the rules, and the clip
/// that keeps a pressed row's highlight (`RowPressStyle`) inside the corners.
struct GlassRowGroup<Content: View>: View {
    /// Where each hairline starts, so rules line up with row text rather than
    /// running under a leading glyph.
    var dividerInset: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            MetricRowDivider()
                                .padding(.leading, dividerInset)
                        }
                        row
                    }
                }
            }
            .clipShape(.rect(cornerRadius: AppLayout.cardRadius))
        }
    }
}

// MARK: - Meter Bar

/// Slim progress capsule toward a finish line (steps, a weekly target).
/// Only where nothing else states the value: a bar beside "5 of 13" or
/// "53 / 85" draws the same fact twice.
struct MeterBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(color)
                .frame(width: fillWidth(in: proxy.size.width))
        }
        .frame(height: height)
        .background(AppColors.meterTrack, in: .capsule)
        .accessibilityHidden(true)
    }

    /// Never narrower than its own cap, so a first step reads as a dot.
    private func fillWidth(in width: CGFloat) -> CGFloat {
        let clamped = min(max(fraction, 0), 1)
        return clamped > 0 ? max(width * clamped, height) : 0
    }
}

// MARK: - Empty State Card

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                // Bare: an identity glyph never sits on a disc.
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let buttonTitle, let buttonAction {
                    GlassButton(title: buttonTitle, style: .primary, action: buttonAction)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Inline Empty State

/// Empty state for a slot that already sits inside a card: a chart well, a
/// section body. `EmptyStateCard` would nest a `GlassCard` in a `GlassCard`.
struct EmptyStateInline: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Glass Cards") {
    ScrollView {
        VStack(spacing: 20) {
            GlassCard { Text("Standard card").foregroundStyle(.white) }
            EmptyStateCard(
                icon: "circle.hexagongrid",
                title: "No habits yet",
                message: "Add your first habit to start a streak.",
                buttonTitle: "Add a habit",
                buttonAction: {}
            )
        }
        .padding()
    }
    .background(AppBackground())
}
