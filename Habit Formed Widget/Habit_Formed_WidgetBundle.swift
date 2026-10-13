import WidgetKit
import SwiftUI

@main
struct Habit_Formed_WidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        Habit_Formed_WidgetLiveActivity()
    }
}
