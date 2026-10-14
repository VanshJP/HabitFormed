import SwiftData
import SwiftUI
import UIKit

/// The Sunday recap: the last seven days as one card, in the daily report's
/// theme and without the habits kept off it, ready to text or share. Edit
/// opens the theme.
struct WeeklyRecapSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.app.rawValue
    @Environment(\.appCanvas) private var canvas
    @AppStorage(AppPreferences.reportAccent) private var accentHex = ""
    @AppStorage(AppPreferences.reportFont) private var fontRaw = ReportFont.standard.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""

    /// The week's last day.
    let end: Date

    @State private var isEditing = false

    init(end: Date) {
        self.end = end.startOfDay
    }

    private var options: ReportOptions {
        ReportOptions(
            theme: ReportTheme(rawValue: themeRaw) ?? .app,
            appLook: canvas.look,
            accentHex: accentHex,
            font: ReportFont(rawValue: fontRaw) ?? .standard
        )
    }

    private var recap: WeeklyRecap {
        WeeklyRecapBuilder.build(
            habits: habits,
            ending: end,
            name: reporterName,
            hidden: ReportOptions.hiddenIDs(from: hiddenRaw)
        )
    }

    var body: some View {
        let recap = recap
        let options = options

        return NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    ReportPreview(width: WeeklyRecapCardView.width) {
                        WeeklyRecapCardView(recap: recap, options: options)
                    }
                    if isEditing {
                        ReportThemeRow(themeRaw: $themeRaw)
                    }
                    // Inline: the page is short, so a pinned bar would float
                    // far below the card.
                    ReportSendBar { ReportCardRenderer.render(recap: recap, options: options) }
                }
                .motion(AppMotion.settle, value: isEditing)
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .background { AppBackground(style: .subtle) }
            .navigationTitle("Weekly recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ReportEditButton(isEditing: $isEditing)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { AppBackground(style: .subtle) }
    }
}
