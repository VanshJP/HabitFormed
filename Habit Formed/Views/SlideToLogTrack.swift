import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. Drag the knob past 75%
/// and it arms (a tick, a check on the knob, "Release"); let go to log, or
/// pull back to disarm. A confident flick from halfway logs too. Once logged
/// the trail fills the track and it settles into a confirmation pill. 44pt
/// tall so the knob meets the hit target.
struct SlideToLogTrack: View {
    let accent: Color
    let isLogged: Bool
    let onComplete: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var isArmed = false
    @GestureState private var isHeld = false

    static let trackHeight: CGFloat = 44
    static let knobSize: CGFloat = 36
    private let armRatio: CGFloat = 0.75
    /// Disarms a little below the arm point, so a thumb resting on the line
    /// does not tick on and off.
    private let disarmRatio: CGFloat = 0.68
    private let flickMinRatio: CGFloat = 0.4

    private var inset: CGFloat { (Self.trackHeight - Self.knobSize) / 2 }

    var body: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - Self.knobSize - inset * 2, 1)
            let progress = min(max(dragX / maxX, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isLogged ? accent.opacity(0.24) : Color.white.opacity(0.08))

                // The trail grows from under the knob, so at rest it is hidden
                // behind it. On log it runs to the end and melts into the pill.
                if isLogged || dragX > 0 {
                    Capsule()
                        .fill(accent.opacity(isLogged ? 0 : 0.35))
                        .frame(
                            width: isLogged ? proxy.size.width - inset * 2 : dragX + Self.knobSize,
                            height: Self.knobSize
                        )
                        .offset(x: inset)
                }

                if isLogged {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .transition(.symbolEffect(.drawOn))
                        Text("Logged")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    Text(isArmed ? "Release" : "Slide to log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(isArmed ? 0.7 : max(0.25, 0.55 - progress * 0.35)))
                        .contentTransition(.opacity)
                        .padding(.leading, Self.knobSize * 0.6)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                if !isLogged {
                    Circle()
                        .fill(accent)
                        .overlay(
                            Image(systemName: isArmed ? "checkmark" : "chevron.right")
                                .font(.footnote.weight(.black))
                                .foregroundStyle(.white)
                                .symbolSwap(isArmed)
                        )
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .scaleEffect(isHeld ? 1.08 : 1)
                        .motion(AppMotion.snap, value: isHeld)
                        .offset(x: inset + dragX)
                        .gesture(drag(maxX: maxX))
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .frame(height: Self.trackHeight)
            .motion(AppMotion.settle, value: isLogged)
        }
        .frame(height: Self.trackHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLogged ? "Logged today" : "Slide to log")
        .accessibilityAddTraits(isLogged ? [] : .isButton)
        .accessibilityAction {
            guard !isLogged else { return }
            Haptics.success()
            onComplete()
        }
        .onChange(of: isLogged) { _, newValue in
            // Snap the knob home whenever the log is removed so the next
            // slide doesn't begin pre-completed.
            if !newValue {
                withAnimation(AppMotion.snap) { dragX = 0 }
            } else {
                dragX = 0
            }
            isArmed = false
        }
    }

    private func drag(maxX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($isHeld) { _, held, _ in held = true }
            .onChanged { value in
                let x = max(0, min(maxX, value.translation.width))
                dragX = x
                if !isArmed, x >= maxX * armRatio {
                    isArmed = true
                    Haptics.tick()
                } else if isArmed, x < maxX * disarmRatio {
                    isArmed = false
                }
            }
            .onEnded { value in
                let x = max(0, min(maxX, value.translation.width))
                let flicked = x >= maxX * flickMinRatio && value.predictedEndTranslation.width >= maxX
                if isArmed || flicked {
                    // The sound plays where the log lands, which knows how
                    // far along the day is; the touch answers right here.
                    Haptics.success()
                    withAnimation(AppMotion.snap) { dragX = maxX }
                    onComplete()
                } else {
                    Haptics.light()
                    withAnimation(AppMotion.snap) { dragX = 0 }
                }
                isArmed = false
            }
    }
}
