import SwiftUI

/// The studio's layouts for the day: your card itself in every layout, side
/// by side, then how the header counts the day where the layout has a count.
struct ReportDayLayoutTool: View {
    let report: DailyReport
    let options: ReportOptions

    @AppStorage(AppPreferences.reportLayout) private var layoutRaw = ReportLayout.list.rawValue
    @AppStorage(AppPreferences.reportRing) private var ringRaw = ReportRing.big.rawValue

    var body: some View {
        let layout = ReportLayout(rawValue: layoutRaw) ?? .list
        VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
            ReportLayoutGallery(
                items: ReportLayout.gallery,
                selection: Binding(get: { layout }, set: { layoutRaw = $0.rawValue }),
                name: \.title
            ) { item in
                ReportPosterView(backdrop: ReportCardView.backdrop(for: options.with(layout: item))) {
                    ReportCardView(report: report, options: options.with(layout: item))
                }
            }
            if layout.showsRing {
                GlassSection("Count") {
                    GlassEffectContainer(spacing: 8) {
                        FlowLayout.chips {
                            ForEach(ReportRing.allCases) { ring in
                                ChoiceChip(title: ring.title, isSelected: ringRaw == ring.rawValue) {
                                    ringRaw = ring.rawValue
                                }
                            }
                        }
                    }
                }
            }
        }
        .motion(AppMotion.settle, value: layoutRaw)
    }
}

/// The studio's layouts for the year: the days as pixels or as months.
struct ReportYearLayoutTool: View {
    let year: YearReport
    let options: ReportOptions

    @AppStorage(AppPreferences.reportYearLayout) private var layoutRaw = YearLayout.pixels.rawValue

    var body: some View {
        let layout = YearLayout(rawValue: layoutRaw) ?? .pixels
        ReportLayoutGallery(
            items: YearLayout.allCases,
            selection: Binding(get: { layout }, set: { layoutRaw = $0.rawValue }),
            name: \.title
        ) { item in
            ReportPosterView(backdrop: ReportBackdrop(options: options)) {
                YearReportCardView(report: year, options: options.with(yearLayout: item))
            }
        }
    }
}

/// Layouts as a rail of live cards, each the real thing in miniature; the
/// picked one is ringed with a gap and named in white, as a look is on
/// `SwatchRail`.
struct ReportLayoutGallery<Item: Identifiable & Hashable, Card: View>: View {
    let items: [Item]
    @Binding var selection: Item
    let name: (Item) -> String
    @ViewBuilder let card: (Item) -> Card

    private let gap: CGFloat = 3

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(items) { item in
                        cell(item).id(item.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AppLayout.pageHorizontal - gap, for: .scrollContent)
            .padding(.horizontal, -AppLayout.pageHorizontal)
            .onAppear { reader.scrollTo(selection.id, anchor: .center) }
        }
    }

    private func cell(_ item: Item) -> some View {
        let isSelected = item == selection
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            selection = item
        } label: {
            VStack(spacing: 6) {
                ReportThumbnail { card(item) }
                    .padding(gap)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.wellRadius + gap, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0), lineWidth: 2)
                    }
                Text(name(item))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
            .contentShape(.rect)
            .motion(AppMotion.snap, value: isSelected)
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(name(item))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
