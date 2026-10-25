import SwiftUI

/// A group of rows on one pane of Liquid Glass, hairlines between rows
/// starting at the text. History, Settings, the report sheet and the add page are
/// built on it. Controls inside read `isOnGlass` and paint plates, never a
/// second pane of glass.
struct Panel<Content: View>: View {
    var dividerInset: CGFloat = RowLayout.dividerInset
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppLayout.cardRadius, style: .continuous)
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
        .clipShape(shape)
        .glassCard(cornerRadius: AppLayout.cardRadius)
    }
}
