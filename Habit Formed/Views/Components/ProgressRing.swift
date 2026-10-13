import SwiftUI

/// A day's completion as a ring on the meter track, in the progress ramp's
/// colour. The week strip draws small ones; the Today card draws the hero.
/// Content (a numeral, a check) goes in the centre through the trailing
/// closure.
struct ProgressRing<Center: View>: View {
    let fraction: Double
    var lineWidth: CGFloat = 4
    var color: Color? = nil
    @ViewBuilder var center: Center

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        ZStack {
            Circle()
                .stroke(AppColors.meterTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    color ?? AppColors.progressColor(for: clamped),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

extension ProgressRing where Center == EmptyView {
    init(fraction: Double, lineWidth: CGFloat = 4, color: Color? = nil) {
        self.init(fraction: fraction, lineWidth: lineWidth, color: color) { EmptyView() }
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRing(fraction: 0).frame(width: 30, height: 30)
        ProgressRing(fraction: 0.4).frame(width: 30, height: 30)
        ProgressRing(fraction: 0.8).frame(width: 30, height: 30)
        ProgressRing(fraction: 1, lineWidth: 10) {
            Text("6/6").font(.metricValue).foregroundStyle(.white)
        }
        .frame(width: 96, height: 96)
    }
    .padding(40)
    .background(AppBackground())
}
