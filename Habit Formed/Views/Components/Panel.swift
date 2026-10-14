import SwiftUI

/// A flat group of rows: one faint fill, hairlines between rows starting at
/// the text. The plain surface History, Settings and the report sheets are
/// built on, where glass would only add noise.
struct Panel<Content: View>: View {
    var dividerInset: CGFloat = RowLayout.dividerInset
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppLayout.tileRadius, style: .continuous)
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
        .background(shape.fill(Color.white.opacity(0.06)))
        .clipShape(shape)
    }
}
