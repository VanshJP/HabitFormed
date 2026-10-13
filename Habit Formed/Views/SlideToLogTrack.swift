import SwiftUI

/// Slide-to-log track, mirroring iOS's slide-to-answer. Drag the knob past 75%
/// and release to log; releasing earlier snaps back. Once logged it collapses
/// into a confirmation pill. 44pt tall so the knob meets the hit target.
struct SlideToLogTrack: View {
    let accent: Color
    let isLogged: Bool
    let onComplete: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var didFire = false

    static let trackHeight: CGFloat = 44
    static let knobSize: CGFloat = 36
    private let triggerRatio: CGFloat = 0.75

    private var inset: CGFloat { (Self.trackHeight - Self.knobSize) / 2 }

    var body: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - Self.knobSize - inset * 2, 1)
            let progress = min(max(dragX / maxX, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isLogged ? accent.opacity(0.24) : Color.white.opacity(0.08))

                // The trail grows from under the knob, so at rest it is hidden
                // behind it instead of showing as a ring around it.
                if !isLogged && dragX > 0 {
                    Capsule()
                        .fill(accent.opacity(0.35))
                        .frame(width: dragX + Self.knobSize, height: Self.knobSize)
                        .offset(x: inset)
                }

                if isLogged {
                    Label("Logged", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(progress > 0.6 ? "Release" : "Slide to log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(max(0.25, 0.55 - progress * 0.35)))
                        .padding(.leading, Self.knobSize * 0.6)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }

                if !isLogged {
                    Circle()
                        .fill(accent)
                        .overlay(
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.black))
                                .foregroundStyle(.white)
                        )
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .offset(x: inset + dragX)
                        .gesture(drag(maxX: maxX))
                }
            }
            .frame(height: Self.trackHeight)
        }
        .frame(height: Self.trackHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLogged ? "Logged today" : "Slide to log")
        .accessibilityAddTraits(isLogged ? [] : .isButton)
        .accessibilityAction {
            guard !isLogged else { return }
            Haptics.success()
            SoundEffects.logChime()
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
            didFire = false
        }
    }

    private func drag(maxX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let x = max(0, min(maxX, value.translation.width))
                dragX = x
                if x > maxX * 0.5 && !didFire {
                    Haptics.tick()
                    didFire = true
                }
                if x < maxX * 0.4 { didFire = false }
            }
            .onEnded { value in
                let x = max(0, min(maxX, value.translation.width))
                if x >= maxX * triggerRatio {
                    Haptics.success()
                    SoundEffects.logChime()
                    withAnimation(AppMotion.snap) { dragX = maxX }
                    onComplete()
                } else {
                    Haptics.light()
                    withAnimation(AppMotion.snap) { dragX = 0 }
                }
                didFire = false
            }
    }
}
