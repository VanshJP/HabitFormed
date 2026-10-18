import SwiftUI

// What every report card is made of, whatever it shows: its palette, its
// ground, the name and date at its top, the note, and the parts the studio
// lets you tap. Painted fills only, so `ImageRenderer` draws all of it.

// MARK: - Palette

/// Ink, wells and accents for a theme: white on the canvases, near-black on
/// the papers. The accent is the look's own unless a palette colour is picked.
struct ReportPalette {
    let isLight: Bool
    let accent: Color
    let paper: Color

    static let defaultPaper = Color(red: 0.984, green: 0.980, blue: 0.965)

    /// `look` is the card's canvas, or nil for paper.
    init(look: CanvasLook?, accentHex: String = "", paper: Color = ReportPalette.defaultPaper) {
        isLight = look == nil
        self.paper = paper
        if !accentHex.isEmpty {
            let picked = Color(hex: accentHex)
            accent = isLight ? picked : picked.glyphTone
        } else {
            accent = look?.accent ?? AppColors.primary
        }
    }

    init(options: ReportOptions) {
        self.init(look: options.look, accentHex: options.accentHex, paper: options.theme.paperColor)
    }

    var ink: Color { isLight ? AppColors.inkOnLight : .white }
    var secondary: Color { ink.opacity(isLight ? 0.6 : 0.55) }
    var faint: Color { ink.opacity(isLight ? 0.4 : 0.45) }
    var well: Color { isLight ? AppColors.inkOnLight.opacity(0.05) : Color.white.opacity(0.07) }
    var rule: Color { isLight ? AppColors.inkOnLight.opacity(0.12) : Color.white.opacity(0.12) }
    /// A perfect day's green, kept deep on paper so it reads.
    var success: Color { isLight ? AppColors.success.mix(with: .black, by: 0.35) : AppColors.success }

    /// A habit's colour, lifted on dark canvases and kept deep on paper so it
    /// clears contrast either way.
    func habitTint(_ hex: String) -> Color {
        dataTint(Color(hex: hex))
    }

    /// Any data colour (a macro, a habit) toned for the card's ground.
    func dataTint(_ color: Color) -> Color {
        isLight ? color : color.glyphTone
    }
}

extension ReportTheme {
    /// The paper a light theme prints on; the canvases never read it.
    var paperColor: Color {
        switch self {
        case .stone: return Color(red: 0.910, green: 0.898, blue: 0.871)
        case .cloud: return Color(red: 0.890, green: 0.910, blue: 0.937)
        default: return ReportPalette.defaultPaper
        }
    }
}

// MARK: - Font

extension ReportFont {
    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    /// Big numbers stay rounded on the default face, as they always were.
    var numerals: Font.Design { self == .standard ? .rounded : design }
}

// MARK: - Ground

/// The card's ground: its canvas, or its paper.
struct ReportCanvas: View {
    let look: CanvasLook?
    let paper: Color

    var body: some View {
        if let look {
            CanvasLookView(look: look, mood: .session)
        } else {
            paper
        }
    }
}

/// What lies under the whole image: the card's own ground, or the colour a
/// layout with a look of its own sits on. The exporter paints it edge to
/// edge (`ReportPosterView`), so a tall card widened for a chat bubble never
/// shows a seam.
enum ReportBackdrop {
    case canvas(CanvasLook)
    case color(Color)

    init(options: ReportOptions) {
        if let look = options.look {
            self = .canvas(look)
        } else {
            self = .color(options.theme.paperColor)
        }
    }
}

struct ReportBackdropView: View {
    let backdrop: ReportBackdrop

    var body: some View {
        switch backdrop {
        case .canvas(let look): CanvasLookView(look: look, mood: .session)
        case .color(let color): color
        }
    }
}

extension View {
    /// A standard card's frame: inset, a fixed width, its canvas or paper
    /// and its type.
    func reportCardFrame(options: ReportOptions, palette: ReportPalette) -> some View {
        padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(width: ReportCardView.width, alignment: .leading)
            .reportCanvas(look: options.look, paper: palette.paper)
            .fontDesign(options.font.design)
    }

    /// Paints the card's ground unless the exporter paints it under the
    /// whole image; in the studio, a tap on it opens the style tools.
    func reportCanvas(look: CanvasLook?, paper: Color) -> some View {
        modifier(ReportCanvasModifier(look: look, paper: paper))
    }

    /// Dynamic Type pinned and the ink's scheme set, so a card looks the same
    /// on every phone it is forwarded to.
    func reportInk(_ palette: ReportPalette) -> some View {
        environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, palette.isLight ? .light : .dark)
    }
}

private struct ReportCanvasModifier: ViewModifier {
    let look: CanvasLook?
    let paper: Color

    @Environment(\.reportPaintsCanvas) private var paintsCanvas
    @Environment(\.reportRegionTap) private var tap

    @ViewBuilder
    func body(content: Content) -> some View {
        let painted = content.background {
            if paintsCanvas { ReportCanvas(look: look, paper: paper) }
        }
        if let tap {
            painted
                .contentShape(.rect)
                .onTapGesture { tap(.canvas) }
        } else {
            painted
        }
    }
}

// MARK: - Header

/// Who and when, at the top of a card, with the day's count (a ring or a
/// number) at its trailing edge when the card has one. A perfect day says so
/// under the date, in green; nothing else is a verdict.
struct ReportCardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    var badge: String? = nil
    let palette: ReportPalette
    var centred = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: centred ? .center : .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let badge {
                    Label(badge, systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.success)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            trailing
        }
    }
}

extension ReportCardHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, badge: String? = nil, palette: ReportPalette, centred: Bool = false) {
        self.init(title: title, subtitle: subtitle, badge: badge, palette: palette, centred: centred) { EmptyView() }
    }
}

// MARK: - Note

/// The line typed for this card only, behind a bar in the accent.
struct ReportNote: View {
    let text: String
    let palette: ReportPalette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(palette.accent)
                .frame(width: 3)
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(palette.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Regions

/// The parts of a card the studio lets you tap to reach their tools.
nonisolated enum ReportRegion: Hashable, Sendable {
    /// The name and date.
    case header
    /// The habits, drawn however the layout draws them.
    case habits
    /// The Apple Health numbers.
    case health
    /// The note.
    case note
    /// The ground under everything.
    case canvas
}

private struct ReportRegionTapKey: EnvironmentKey {
    static var defaultValue: ((ReportRegion) -> Void)? { nil }
}

private struct ReportActiveRegionKey: EnvironmentKey {
    static let defaultValue: ReportRegion? = nil
}

private struct ReportPaintsCanvasKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Set only by the report studio: a tap on a part of the card. Nil
    /// everywhere else, so the image sent and the send page's preview never
    /// react to a touch.
    var reportRegionTap: ((ReportRegion) -> Void)? {
        get { self[ReportRegionTapKey.self] }
        set { self[ReportRegionTapKey.self] = newValue }
    }

    /// The part whose tools the studio is showing, outlined brighter.
    var reportActiveRegion: ReportRegion? {
        get { self[ReportActiveRegionKey.self] }
        set { self[ReportActiveRegionKey.self] = newValue }
    }

    /// False while `ReportPosterView` paints the ground under the whole image.
    var reportPaintsCanvas: Bool {
        get { self[ReportPaintsCanvasKey.self] }
        set { self[ReportPaintsCanvasKey.self] = newValue }
    }
}

extension View {
    /// Marks a part of the card the studio can open: outlined in dashes and
    /// tappable there, untouched everywhere else. `outlined` is off for the
    /// layouts with their own paper, where a tap anywhere opens the layouts.
    func reportRegion(_ region: ReportRegion, outlined: Bool = true) -> some View {
        modifier(ReportRegionModifier(region: region, outlined: outlined))
    }
}

private struct ReportRegionModifier: ViewModifier {
    let region: ReportRegion
    let outlined: Bool

    @Environment(\.reportRegionTap) private var tap
    @Environment(\.reportActiveRegion) private var active

    @ViewBuilder
    func body(content: Content) -> some View {
        if let tap {
            content
                .overlay {
                    if outlined {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .inset(by: -6)
                            .stroke(
                                Color.primary.opacity(active == region ? 0.9 : 0.3),
                                style: StrokeStyle(lineWidth: active == region ? 2 : 1.5, dash: [5, 4])
                            )
                    }
                }
                .contentShape(.rect)
                .onTapGesture { tap(region) }
                .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }
}
