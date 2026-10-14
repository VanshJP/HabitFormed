import SwiftData
import SwiftUI
import UIKit

/// The Sunday recap: the last seven days as one card, in the daily report's
/// theme and without the habits kept off it, ready to text or share.
struct WeeklyRecapSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Habit.sortOrder), SortDescriptor(\Habit.createdAt)])
    private var habits: [Habit]

    @AppStorage(AppPreferences.reporterName) private var reporterName = ""
    @AppStorage(AppPreferences.reportTheme) private var themeRaw = ReportTheme.classic.rawValue
    @AppStorage(AppPreferences.reportHiddenHabits) private var hiddenRaw = ""

    /// The week's last day.
    let end: Date


    init(end: Date) {
        self.end = end.startOfDay
    }

    private var theme: ReportTheme { ReportTheme(rawValue: themeRaw) ?? .classic }

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
        let theme = theme

        return NavigationStack {
            PageScrollView {
                VStack(alignment: .leading, spacing: AppLayout.chapterSpacing) {
                    ReportPreview(width: WeeklyRecapCardView.width) {
                        WeeklyRecapCardView(recap: recap, theme: theme)
                    }
                    ReportThemeRow(themeRaw: $themeRaw)
                }
                .padding(.horizontal, AppLayout.pageHorizontal)
                .padding(.bottom, AppLayout.pageBottom)
            }
            .background { AppBackground(style: .subtle) }
            .safeAreaBar(edge: .bottom) {
                ReportSendBar { ReportCardRenderer.render(recap: recap, theme: theme) }
            }
            .navigationTitle("Week recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { AppBackground(style: .subtle) }
    }
}
