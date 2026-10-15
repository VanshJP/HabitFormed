import SwiftUI

extension FlowLayout {
    /// Rows of chips, their capsules 10 apart either way. A chip's hit frame
    /// already sits 5pt clear of its capsule, so lines stack frame to frame
    /// and the gap across matches the gap down.
    static let chips = FlowLayout(spacing: 10, lineSpacing: 0)
}

/// A one-of-many chip: a timer length, an interval, a layout, an idea for
/// a habit. `tint` colors the glyph and, on the canvas, the glass, so an
/// idea reads as a suggestion rather than a setting.
struct ChoiceChip: View {
    let title: String
    var icon: String? = nil
    var tint: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isSelected else { return }
            Haptics.selection()
            action()
        } label: {
            ChipFace(title: title, icon: icon, tint: tint, isOn: isSelected, isChoice: true)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A chip that switches one thing on or off, for picking several: the
/// habits and extras a report card shows. `tint` colors the glyph while on.
struct ToggleChip: View {
    let title: String
    var icon: String? = nil
    var tint: Color? = nil
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Haptics.selection()
            isOn.toggle()
        } label: {
            ChipFace(title: title, icon: icon, tint: tint, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Both chips' face: solid white with ink when on, `controlChrome` when off
/// (interactive glass on the canvas, a plate inside a glass panel). The
/// glass stays put and the white sits on it, so choosing never rebuilds
/// the glass. Off text is hierarchical so it adapts to the glass under it:
/// primary for a choice, secondary (and a dimmer glyph) for a toggle that
/// leaves something out. Put a row of chips on the canvas in a
/// `GlassEffectContainer`.
private struct ChipFace: View {
    let title: String
    let icon: String?
    var tint: Color? = nil
    let isOn: Bool
    var isChoice = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(glyphColor)
                    .symbolEffect(.bounce, value: isOn)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(isOn ? AnyShapeStyle(AppColors.inkOnLight) : isChoice ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .background(Capsule().fill(isOn ? AppColors.solidWhite : .clear))
        .controlChrome(in: Capsule(), tint: tint.map { $0.opacity(0.3) })
        .frame(minHeight: AppLayout.minHitTarget)
        .contentShape(.rect)
        .motion(AppMotion.snap, value: isOn)
    }

    private var glyphColor: AnyShapeStyle {
        if isOn { return AnyShapeStyle(tint ?? AppColors.inkOnLight) }
        if isChoice { return tint.map { AnyShapeStyle($0.glyphTone) } ?? AnyShapeStyle(.secondary) }
        return AnyShapeStyle(.tertiary)
    }
}
