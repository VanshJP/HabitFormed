import SwiftUI

/// The capsule that follows a log on Today: what just happened, and one word
/// to take it back. A log by slide is fast enough to happen by accident, so
/// the way back sits where the thumb already is.
///
/// It leaves on its own after `lifetime`, or at once when swiped up or to
/// either side, the way a notification banner does. Dragging it holds it,
/// and letting go without a swipe starts the time again.
struct UndoToast: View {
    let message: String
    /// A check for a log, the way back for one taken away.
    var icon = "checkmark.circle.fill"
    var tint: Color = AppColors.success
    /// How long it stays untouched. A new message starts it again.
    var lifetime: Duration = .seconds(4)
    let onUndo: () -> Void
    /// Time ran out or it was swiped away.
    let onDismiss: () -> Void

    @Environment(\.glassAppearance) private var glassAppearance

    @GestureState private var isHeld = false
    @State private var offset: CGSize = .zero
    @State private var isLeaving = false

    /// How far a release, flick included, must carry it to send it off.
    private let leaveUp: CGFloat = 40
    private let leaveSideways: CGFloat = 120

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint.glyphTone)
                // Lands again when the toast turns into "Perfect day".
                .symbolEffect(.bounce, value: message)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                Haptics.undo()
                onUndo()
            } label: {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .plateChrome(in: Capsule())
                    .frame(minHeight: AppLayout.minHitTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(GlassPressStyle())
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        // The whole capsule takes the swipe, the space beside the words too.
        .contentShape(Capsule())
        .glassEffect(.regular.tint(glassAppearance.glassTint), in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .offset(offset)
        .opacity(1 - min(hypot(offset.width, min(offset.height, 0)) / 240, 0.6))
        .gesture(swipe)
        .onChange(of: isHeld) { _, held in
            // A drag the system took over never ends; put the toast back.
            if !held, !isLeaving, offset != .zero {
                withMotion(AppMotion.snap) { offset = .zero }
            }
        }
        .task(id: Countdown(message: message, lifetime: lifetime, isHeld: isHeld)) {
            guard !isHeld else { return }
            guard (try? await Task.sleep(for: lifetime)) != nil, !isLeaving else { return }
            onDismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) { onDismiss() }
        .accessibilityAction(named: "Dismiss") { onDismiss() }
    }

    /// Up and sideways follow the finger; down gives a little and springs back.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($isHeld) { _, held, _ in held = true }
            .onChanged { value in
                guard !isLeaving else { return }
                let drag = value.translation
                offset = CGSize(width: drag.width, height: drag.height < 0 ? drag.height : drag.height / 5)
            }
            .onEnded { value in
                guard !isLeaving else { return }
                let end = value.predictedEndTranslation
                if end.height < -leaveUp || abs(end.width) > leaveSideways {
                    leave(toward: end)
                } else {
                    withMotion(AppMotion.snap) { offset = .zero }
                }
            }
    }

    /// Carries on the way it was thrown while Today takes it away.
    private func leave(toward end: CGSize) {
        isLeaving = true
        let sideways = abs(end.width) > abs(end.height)
        withMotion(AppMotion.settle) {
            offset = sideways
                ? CGSize(width: end.width > 0 ? 480 : -480, height: offset.height)
                : CGSize(width: offset.width, height: -160)
            onDismiss()
        }
    }

    private nonisolated struct Countdown: Hashable {
        let message: String
        let lifetime: Duration
        let isHeld: Bool
    }
}

#Preview {
    ZStack(alignment: .top) {
        AppBackground(style: .subtle)
        VStack(spacing: 16) {
            UndoToast(message: "Read logged", onUndo: {}, onDismiss: {})
                .padding(.horizontal, 16)
            UndoToast(message: "Perfect day", lifetime: .seconds(6), onUndo: {}, onDismiss: {})
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }
}
