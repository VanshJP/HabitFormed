import SwiftUI

/// How much of the browsed day is done, and the door to its report. On a past
/// day it also explains how to fix a missed log and offers the way back.
struct DayProgressCard: View {
    let summary: DaySummary
    let isToday: Bool
    let onShare: () -> Void
    let onBackToToday: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ProgressRing(fraction: summary.fraction, lineWidth: 8) {
                        VStack(spacing: 0) {
                            Text("\(summary.done)")
                                .font(.metricValue)
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(value: Double(summary.done)))
                            Text("of \(summary.expected)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 84, height: 84)
                    .motion(AppMotion.settle, value: summary.done)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { buttons }
                    VStack(spacing: 10) { buttons }
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        GlassButton(
            title: isToday ? "Share today's report" : "Share this day",
            icon: "square.and.arrow.up",
            style: .secondary,
            size: .small,
            fullWidth: true,
            action: onShare
        )
        if !isToday {
            GlassButton(title: "Back to today", style: .outline, size: .small, fullWidth: true) {
                Haptics.selection()
                onBackToToday()
            }
        }
    }

    private var headline: String {
        if summary.expected == 0 { return summary.done > 0 ? "Bonus day" : "Nothing due" }
        if summary.isPerfect { return "Perfect day" }
        if isToday { return summary.remaining == 1 ? "1 to go" : "\(summary.remaining) to go" }
        return "\(summary.done) of \(summary.expected) done"
    }

    private var detail: String {
        if isToday {
            if summary.expected == 0 { return "Nothing is scheduled today. Log anything you like." }
            if summary.isPerfect { return "Every habit is logged. Send the report." }
            return "\(summary.done) of \(summary.expected) habits done today."
        }
        return "Tap a tile's pill to fix a forgotten log."
    }
}
