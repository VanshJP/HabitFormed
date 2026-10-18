import SwiftUI

/// A set of the studio's tools.
enum ReportTool: String, CaseIterable, Identifiable {
    case layout
    case content
    case style

    var id: String { rawValue }

    var title: String {
        switch self {
        case .layout: return "Layout"
        case .content: return "Content"
        case .style: return "Style"
        }
    }

    var icon: String {
        switch self {
        case .layout: return "rectangle.3.group"
        case .content: return "checklist"
        case .style: return "paintpalette"
        }
    }

    /// The part of the card these tools are for, outlined brighter.
    var region: ReportRegion? {
        switch self {
        case .layout: return .habits
        case .content: return .header
        case .style: return nil
        }
    }

    /// The week's card has one layout, so it has no Layout tools.
    static func tools(for scope: ReportScope) -> [ReportTool] {
        scope == .week ? [.content, .style] : allCases
    }

    /// Where a tap on a part of the card leads.
    static func tool(for region: ReportRegion, in scope: ReportScope) -> ReportTool {
        let wanted: ReportTool
        switch region {
        case .habits: wanted = .layout
        case .canvas: wanted = .style
        case .header, .health, .note: wanted = .content
        }
        return tools(for: scope).contains(wanted) ? wanted : .content
    }
}

/// The card being edited and its tools, like a photo editor: the whole card
/// on the stage, every change showing at once, and the tools in a dock
/// under it. A tap on a part of the card (the name, the habits, the ground)
/// opens that part's tools, so editing is done on the card itself.
struct ReportStudio<Stage: View, Tools: View>: View {
    let tools: [ReportTool]
    @Binding var tool: ReportTool
    @ViewBuilder let stage: Stage
    @ViewBuilder let content: Tools

    var body: some View {
        GeometryReader { proxy in
            let dock = min(max(proxy.size.height * 0.46, 250), 380)
            VStack(spacing: 10) {
                ReportStage { stage }
                    .padding(.horizontal, AppLayout.pageHorizontal)
                    .padding(.top, 4)
                    .frame(maxHeight: .infinity)
                VStack(spacing: 4) {
                    tabs
                    ScrollView {
                        content
                            .padding(.horizontal, AppLayout.pageHorizontal)
                            .padding(.top, 8)
                            .padding(.bottom, AppLayout.pageBottom)
                            .readableColumn()
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                }
                .frame(height: dock)
            }
        }
    }

    private var tabs: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(tools) { item in
                    ChoiceChip(title: item.title, icon: item.icon, isSelected: tool == item) {
                        withMotion(AppMotion.settle) { tool = item }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
