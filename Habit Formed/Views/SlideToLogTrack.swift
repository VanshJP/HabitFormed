import SwiftUI

/// Simplified slide-to-log track. Drag the knob past 75% and release to log;
/// releasing earlier snaps back. Once logged, collapses into a confirmation pill.
struct SlideToLogTrack: View {
    let accent: Color
    let isLogged: Bool
    let onComplete: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var didFire = false

    private let knobSize: CGFloat = 30
    private let trackHeight: CGFloat = 34
    private let triggerRatio: CGFloat = 0.75

    var body: some View {
        GeometryReader { proxy in
            let maxX = max(proxy.size.width - knobSize, 1)
            let progress = min(max(dragX / maxX, 0), 1)

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(isLogged ? accent.opacity(0.28) : Color.white.opacity(0.08))

                // Fill trail
                if !isLogged {
                    Capsule()
                        .fill(accent.opacity(0.45))
                        .frame(width: dragX + knobSize)
                }

                // Labels
                if isLogged {
                    Label("Logged", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                } else {
                    Text(progress > 0.6 ? "RELEASE" : "SLIDE TO LOG")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(max(0.2, 0.55 - progress * 0.35)))
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }

                // Knob
                if !isLogged {
                    Circle()
                        .fill(accent)
                        .overlay(
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: accent.opacity(0.4), radius: 5, y: 1)
                        .frame(width: knobSize, height: knobSize)
                        .offset(x: dragX)
                        .gesture(drag(maxX: maxX))
                        .accessibilityLabel("Slide to log habit")
                }
            }
            .frame(height: trackHeight)
        }
        .frame(height: trackHeight)
        .onChange(of: isLogged) { _, newValue in
            // Snap the knob back to the start whenever the habit is
            // un-logged so the next slide doesn't begin pre-completed.
            if !newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    dragX = 0
                }
                didFire = false
            } else {
                dragX = 0
                didFire = false
            }
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragX = maxX }
                    onComplete()
                } else {
                    Haptics.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dragX = 0 }
                }
                didFire = false
            }
    }
}
