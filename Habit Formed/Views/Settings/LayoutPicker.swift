import SwiftUI

/// Today's tiles or rows, each drawn as a small picture of Today in that
/// layout.
struct LayoutPicker: View {
    @Binding var selection: TodayLayout

    var body: some View {
        SketchPicker(items: TodayLayout.allCases, selection: $selection, name: \.title) { layout in
            LayoutSketch(layout: layout)
        }
    }
}

/// Today in miniature: two filled squares among four, or one filled row among
/// three, since done is a habit filled with its color.
private struct LayoutSketch: View {
    let layout: TodayLayout
    @Environment(\.appCanvas) private var canvas

    var body: some View {
        switch layout {
        case .tiles:
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                GridRow { block(done: true); block(done: false) }
                GridRow { block(done: false); block(done: true) }
            }
            .aspectRatio(1, contentMode: .fit)
        case .rows:
            VStack(spacing: 5) {
                block(done: true)
                block(done: false)
                block(done: false)
            }
        }
    }

    private func block(done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(done ? canvas.look.accent : Color.white.opacity(0.14))
    }
}
