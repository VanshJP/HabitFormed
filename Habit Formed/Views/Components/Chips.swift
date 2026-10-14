import SwiftUI

/// A one-of-many chip: a timer length, an interval, a layout, an idea for
/// a habit. `tint` colors the glyph, chosen or not.
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
            ChipFace(title: title, icon: icon, tint: tint, isOn: isSelected, keepsTint: true)
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
/// the glass. An off toggle dims its glyph too, unless `keepsTint`. Put a
/// row of chips on the canvas in a `GlassEffectContainer`.
private struct ChipFace: View {
    let title: String
    let icon: String?
    var tint: Color? = nil
    let isOn: Bool
    var keepsTint = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(glyphColor)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(isOn ? AppColors.inkOnLight : Color.white.opacity(0.7))
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .background(Capsule().fill(isOn ? AppColors.solidWhite : .clear))
        .controlChrome(in: Capsule())
        .frame(minHeight: AppLayout.minHitTarget)
        .contentShape(.rect)
        .motion(AppMotion.snap, value: isOn)
    }

    private var glyphColor: Color {
        if isOn { return tint ?? AppColors.inkOnLight }
        if keepsTint, let tint { return tint.glyphTone }
        return Color.white.opacity(0.45)
    }
}
