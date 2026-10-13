import SwiftUI

/// The inset hairline between rows that share one plate (`GlassRowGroup`).
struct MetricRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
    }
}
