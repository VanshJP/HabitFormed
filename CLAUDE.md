# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repo.

## Project

**Habit Formed**: a minimalist, gesture-driven iOS habit tracker. Its look
is SpeakUp's design system, ported (deep-navy canvas, Liquid Glass plates,
colour only in data and identity, one loud CTA per screen). Inspired
functionally by the Streaks app: a small grid of tiles, each representing one
habit, with streak counts and 7-day completion dots. The signature feature is
the **daily report**: one card that you send to friends, with a theme and
switches for what to leave out.

- **Platform:** iOS 26.0+ (iPhone + iPad), plus a widget extension
  (Home Screen widget and the timer Live Activity).
- **Language:** Swift 5 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Mark new pure types
  `nonisolated` (see `DayLedger`, `DailyReport`, `ReportOptions`).
- **UI:** SwiftUI. UIKit only for haptics (`Extensions/Haptics.swift`), the
  share sheet (`SharePresenter`), and Messages (`MessageComposer`).
- **Persistence:** SwiftData (`@Model`): `Habit`, `HabitCompletion`. Do
  **not** introduce CoreData, `FileManager`, or `UserDefaults` for habit
  data. Preferences (app look, report name, report theme and switches,
  report reminder) use `@AppStorage` with keys in
  `Services/AppPreferences.swift`.
- **Health data:** HealthKit, wrapped in `Services/HealthKitService.swift`
  (`@Observable`, injected via `.environment`).

## Build / run

```sh
# Build for the iOS Simulator
xcodebuild -project "Habit Formed.xcodeproj" \
  -scheme "Habit Formed" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build

# Open in Xcode
open "Habit Formed.xcodeproj"
```

The Xcode project uses `objectVersion = 77` with
`PBXFileSystemSynchronizedRootGroup`, so any file dropped into the
`Habit Formed/` folder is picked up automatically; no `pbxproj` edits
are needed when adding new Swift files.

`Habit Formed Widget/` is synchronized into **both** targets. A file there
is shared (compiled into the app and the extension) unless it is listed in
the app target's membership exceptions in `project.pbxproj`. Shared files
(`WidgetSnapshot`, `WidgetStore`, `LogHabitIntent`, the timer attributes and
intent) stay Foundation-only and `nonisolated`; a new widget-only file
(views, providers, `Widget` structs) must be added to that exception list,
the one sanctioned `pbxproj` edit for files.

## Folder layout

```
Habit Formed/
├── Habit_FormedApp.swift     # App entry: ModelContainer (Habit, HabitCompletion) + services
├── ContentView.swift         # Today tab: month control, week strip, the habits, undo toast
├── Models/                   # Habit, HabitCompletion, DayLedger, ReminderTiming, ReportOptions (+ ReportTheme)
├── Services/                 # HealthKit, notifications, timer, widget sync, report + weekly recap builders,
│                             #   renderer, share, Messages
├── Theme/                    # Ported SpeakUp tokens: AppColors, AppLayout, AppType, AppMotion,
│                             #   GlassStyles, AppBackground, AppCanvas, CanvasLook, AppearanceEnvironment
├── Extensions/               # Haptics, Date helpers (streak math, trailing days)
└── Views/
    ├── Components/           # Ported SpeakUp components (GlassCard, GlassButton, PageTitle, ...) and the
│                             #   app's own: Panel, Chips (ChoiceChip, ToggleChip), SwatchRail
    ├── Today/                # WeekStrip, TodayHabitList, DateBrowserSheet, ArrangeHabitsSheet
    ├── AddHabit/             # AddHabitView, HabitDraft (+ HabitTemplate), form sections (ideas, look, how you log it,
│                             #   how often, reminder), asked as plain questions with chips
    ├── History/              # HistoryHero, ConsistencyHeatMap (+ legend), DayRow
    ├── Report/               # DailyReportSheet, ReportCardView, WeeklyRecapSheet, WeeklyRecapCardView (+ Grid),
    │                         #   ReportSheetParts (preview, theme row, send bar shared by both sheets)
    ├── Settings/             # SettingsView
    ├── RootView.swift        # TabView (Today, History), mini timer banner, root sheets
    ├── HabitTileView.swift   # One grid tile
    ├── HabitRowView.swift    # One compact row (the Rows layout), with RowTimerButton
    ├── HabitActions.swift    # HabitActions + HabitContextMenu, shared by tiles, rows, done chips
    ├── HabitStatusLine.swift # Streak and cadence line, shared by tiles and rows
    ├── HabitDetailView.swift # Per-habit page: streak hero, tappable history calendar, log + note, recent logs
    ├── HistoryView.swift     # One page: hero, 12-week map, streaks, days that open in place
    ├── TimerView.swift       # Per-habit countdown session (auto-logs on finish)
    ├── CompletionFill.swift  # Done as a tile or row filled with the habit's color
    └── SlideToLogTrack.swift # iPhone slide-to-answer style log knob

Habit Formed Widget/          # Widget extension (see the membership note above)
├── TodayWidget.swift         # Home Screen widget, timeline provider (widget-only)
├── TodayWidgetViews.swift    # Small and medium layouts, WidgetPalette (widget-only)
├── WidgetSnapshot.swift      # Shared: what the widget shows, pending widget logs
├── WidgetStore.swift         # Shared: App Group read/write (group.com.vansh.Habit-Formed)
├── LogHabitIntent.swift      # Shared: the widget's log button
├── WidgetLink.swift          # Shared: habitformed:// links that RootView opens
├── PrivacyInfo.xcprivacy     # Shared: the privacy manifest for both bundles (UserDefaults reasons)
└── Habit_Formed_WidgetLiveActivity.swift # Timer Live Activity (widget-only)
```

## Interaction model

`RootView` hosts two tabs, each with no navigation bar (the page title is
the header):

- **Today**: `ContentView`. No page title: the top row is the month
  ("October ⌄", which opens the calendar) and a capsule holding the
  perfect-day `StreakChip` (only once a streak exists), add (+) and Settings
  (gear, pushed). Right under it the `WeekStrip` is the date control: one
  row of 7 rings drawn on the canvas, each holding its weekday and date and
  filling as that day's habits are logged (closed and green on a perfect
  day). The selected day sits on a soft circle of glass, never solid
  white. Strip taps only change the selected day; the strip itself moves
  only when the calendar picks an older day (`stripAnchor`). Then the
  grid's section,
  titled "Habits" for today or the browsed day's name, with the day's count
  beside the title ("2 of 6 done"), and "Share report" (plus a "Today" link
  while browsing another day). Progress is said once, in that header.
  The section lists every habit, as tiles or rows (`TodayLayout`, picked
  in Settings), and each stays in place: **done is the tile or row filled
  with its habit's color** (`CompletionFill`), so a finished day is a grid
  of filled squares and needs no other line to say so.
- **History**: `HistoryView`, one page with no picker. `HistoryHero` is
  the perfect-day streak as one big number, with the best and the last
  seven days under it and a "Recap" button. Then the 12-week map with its
  legend, per-habit streak rows (tap opens the detail sheet), and the days:
  each a `DayRow` (name, logged glyphs, "2 of 3") that opens in place to
  list its logs (long-press one to remove it) and a "Share report" row.
- **Settings**: pushed from the gear. Today (layout, arrange, log sound),
  Reports (name on cards, daily reminder with its time, Sunday recap) and
  Look (canvas rail, glass). No captions; few-way choices are chips in
  their row.

The rule across screens: say each fact once, keep captions for what is not
obvious, paint only the selected choice in a grid, and prefer one line of
text over another card.

Each habit tile responds to three gestures, and so do rows. They all take one `HabitActions` and share
`HabitContextMenu`; keep it that way for new surfaces:

| Gesture                  | Action                                |
|--------------------------|---------------------------------------|
| **Single tap**           | Open `HabitDetailView` (history + log) |
| **Slide knob right**     | Log today in place (`SlideToLogTrack`) |
| **Long-press**           | `contextMenu`: Log / Undo today, Start timer, Edit, Arrange, Delete |

The slide-to-log knob mirrors iOS's slide-to-answer. As it travels, the
habit's color pours out of it (a circle centred on the knob that reaches
the tile's far corner as the knob arrives) and its chevron winds clockwise
into clock hands showing the time right now (the knob's disc is the face),
holds there, then folds into a check (`ClockGlyph`: one stroke, a corner
and two legs moving between poses); at ~75% the check is whole and it
arms (a tick and a small pop), and letting go logs. Holding the knob keeps
the long-press menu shut, so a pause mid-slide never opens it. Release earlier to cancel; a flick from halfway logs too. The
surface owns the knob's `progress`, so an undo plays it all backwards. The
track is 44pt tall with the 36pt knob inset in it; its gray pill is what
is left to slide, shrinking behind the knob over the fill. Flat, no
shadows: the knob is a disc a step lighter than the habit's color, so it
stays distinct on the fill. Done, the channel and
the knob melt into the fill and only the white check stays. Every log from
the grid shows an `UndoToast` for four seconds; the log that finishes a
perfect day turns it into "Perfect day" with a "Send report" button for
six.

Logs from Today chime through `ContentView.logToday`, a pentatonic step
higher as the day fills (`SoundEffects.logChime(progress:)`), so callers
there play the haptic only. The perfect day adds `SoundEffects.perfectDay`
(a rolled chord on its own player) and `Haptics.celebrate` over the
confetti. Taking back your own log is `Haptics.undo`, not a warning.

When the grid shows a **past day**, the bottom row of every tile becomes a
pill that toggles that day's log (fixing a forgotten day is one tap). The
detail sheet's calendar does the same per day.

All log writes go through `Habit.log(on:in:)` and `Habit.removeLog(on:in:)`
so a day never holds two completions. Deleting a habit goes through
`HabitLifecycle.delete` (stops its timer and reminders first).

### Day ledger

`Models/DayLedger.swift` is the one source for "X of Y done", the week strip
rings, the perfect-day streak and the report's counts. Per habit and day a
`DayStatus` is `done`, `open` (today, not yet), `missed` (past day),
`flexible` (weekly habits on an unlogged day: never a miss), or `resting`
(interval countdown running, or before the habit existed). Only done, open
and missed count toward the total. A perfect day logged everything expected;
days that expected nothing are skipped by the streak.

### Reminders

A reminder learns by default (`Habit.reminderLearnsTime`): once a habit has
`ReminderTiming.minimumLogs` logs made on the day they count for, it fires
30 minutes before the median time of the latest ones (rounded down to five
minutes), so plants usually watered at 10:00 AM get a 9:30 AM nudge. Until
then, with learning off, and for health habits (whose logs are written by
sync) it fires at the set `reminderHour`/`reminderMinute`. Everything reads
`Habit.reminderFireTime`. Logs made within those 30 minutes after a learned
reminder are marked `HabitCompletion.followedReminder` and left out of
learning, so answering the reminder never walks it earlier. Reminders for
manual and timer habits carry a "Log it" action that `NotificationRouter`
handles in the background.

A reminder stays quiet on a day already handled (logged, or a weekly
habit's met week). A daily alert is one repeating request; when one of the
next seven firings is handled, the habit's week splits into seven weekday
requests, the handled ones becoming one-shots a week out, and the next sync
folds it back. Habit reminders stay within `habitReminderBudget` (56 of
iOS's 64 pending), and habits past it keep the plain daily alert.

### Widgets

The widget never opens SwiftData. `WidgetSync` (app side) writes a
`WidgetSnapshot` (today's page plus tomorrow's, so the widget flips at
midnight on its own) to the App Group whenever `WidgetSync.signature`
changes, and reloads timelines only when the snapshot differs. Tapping the
small widget opens today's report (`WidgetLink.report`, handled in
`RootView.onOpenURL`; the scheme is registered in
`Habit-Formed-Info.plist`). The medium
widget's log button runs `LogHabitIntent`, which queues a
`PendingWidgetLog` and marks the habit done in the snapshot; the app writes
the real log (keeping the tap time as `loggedAt`) on launch, on returning to
the foreground, or at once when the intent ran in the app's process. Always
apply pending logs before writing a snapshot.

### Timers

Habits can carry an optional countdown timer
(`Habit.timerDurationSeconds`, set in the add sheet's "How do you log it?" → Timer).
`TimerView` is a foreground session with a circular progress ring,
pause/resume/reset, and auto-logs the habit on completion (only if not
already logged today). Closing before completion does **not** log.

### Daily report

Keep it simple: one report, everything on by default, switches to take
things out. No templates, layouts or placeholder tokens.

- `ReportOptions` is the whole configuration: a `ReportTheme` (six canvases
  or paper), hidden habits, and switches for streaks, notes, last 7 days,
  calories in vs out, and activity. The sheet keeps them in `@AppStorage`;
  the optional note is for one card only.
- `DailyReportBuilder` turns habits + options into a `DailyReport` value;
  `ReportCardView` draws it at a fixed 390pt width with painted fills only
  (no glass: `ImageRenderer` cannot draw it), using `ReportPalette` for ink
  on canvas or paper; `ReportCardRenderer` renders it (scale 2 for the
  preview, 3 for sending).
- `DailyReportSheet`: live preview, theme rail, "On the card" as
  `ToggleChip`s (the habits, then Streaks, Habit notes, Last 7 days,
  Calories, Activity), one panel of fields (name the first time, calories
  eaten while Calories is on, this card's note), then Text it (`MessageComposer`, Messages with the image
  attached) and Share (`SharePresenter`; Save and Copy live in the share
  sheet). Both send the card alone, with no text typed under it. The card prints the reporter's name
  (`AppPreferences.reporterName`) so a forwarded card still says whose day
  it was. Calories eaten come from Apple Health and can be typed over before
  sending.
- An optional daily reminder (`report-reminder`) opens today's report.

### Weekly recap

The Sunday recap is the same idea for a week: `WeeklyRecapBuilder` turns
habits into a `WeeklyRecap` value for the last seven days (perfect days
against the week before, each habit's seven `DayStatus` squares, the
longest streak and the habit that climbed most), and `WeeklyRecapCardView`
draws it under the daily card's rules. `WeeklyRecapSheet` shares the
daily report's theme, hidden habits and name, and its preview, theme row
and send bar (`ReportSheetParts`). It opens from History's "Recap"
button, from an optional Sunday 7 PM nudge (`recap-reminder`, switched on
in Settings), or from `WidgetLink.recap`.

## Conventions

The design system is SpeakUp's; when in doubt, match
`../SpeakUp-App/docs/features/ui-design-system.md`.

- **Surfaces:** cards are `GlassCard` / `.glassCard(cornerRadius:tint:)`
  (Liquid Glass). Never stack glass on glass: inside a card use
  `.plateChrome(in:)`, `.inputWell()`, or `.controlChrome(in:)` (which
  branches on `\.isOnGlass`). Radii and padding come from `AppLayout`
  (card 20 / 16, tile 16 / 12, well 12). Groups of rows (History,
  Settings, the report and add sheets) sit on a `Panel`, one pane of glass
  with hairlines. Chips use `controlChrome`, so a row of them on the canvas
  is interactive glass (wrap it in a `GlassEffectContainer`) and inside a
  panel they are plates. Alignment: text outside a card (page titles,
  section headers, the History hero) sits on the card's edge, and
  everything inside a card or tile sits `AppLayout.tilePadding` (14) in. The material is glass; nothing draws its own
  bevel, gradient or glow. Names: the daily card is the "report", the
  weekly one the "recap".
- **Colour:** only `AppColors`. Identity tints stay at 0.06 on a tile
  (`AppColors.identityTint`) and 0.10 when featured (`featuredTint`); the
  one solid use of a habit's color is Today's done fill, with the glyph
  turning white on it. A habit's glyph otherwise uses `color.glyphTone`
  (lifted toward white). Habit colors come from `AppColors.tilePalette`.
- **Glyphs:** bare, never on a disc or plate (`IconChip`, `RowGlyph`).
- **Buttons:** `GlassButton` (primary is solid white, one per screen);
  words-only buttons use `.buttonStyle(.textLink)`. Selected chips and
  segments are solid white with `AppColors.inkOnLight` text. The week
  strip is the exception: its selected day is a soft circle of glass.
- **Type:** text styles that scale (`.subheadline.weight(.semibold)` etc.);
  numerals use `.displayNumeral`, `.ringNumeral`, `.metricValue`,
  `.statValue`. Small caps labels use `.eyebrowStyle()`; never hand-roll
  uppercase + tracking.
- **Sections:** `GlassSection("Title", meta:)` with a sentence-case header;
  `detail:` puts one fact right after the title.
- **Pages:** `PageScrollView` + `.pageContentInsets()` on root tabs; sheets
  close with `Button(role: .close)` top leading; deletes confirm with an
  `.alert("Delete this X?")`.
- **Motion:** `AppMotion` tokens and `.motion(_:value:)`, which respects
  Reduce Motion.
- **Haptics:** route every tactile moment through `Haptics.*`. Don't
  instantiate `UIImpactFeedbackGenerator` inline.
- **Streak math:** call `Date.calculateStreak(from:today:)`; do not
  duplicate the day-grace logic. Schedule-aware streaks go through
  `Habit.displayStreak` (or `displayStreak(asOf:)` for a past day). The
  perfect-day streak is `DayLedger.perfectStreak`.
- **Scheduling:** `HabitFrequency` is `daily`, `weekly`
  (`weeklyTarget`, N times per week), or `interval` (`intervalDays`,
  log once every N days; logging resets the countdown). Interval is
  manual-swipe only; auto-reset to daily when track type becomes
  timer/health (`HabitDraft.setKind`).
- **Copy:** no em dashes anywhere (strings or comments). Sentence case.
  Keep UI copy plain and short.
- **Numbers:** convert user-typed or HealthKit doubles with
  `Double.safeRounded`, never `Int(x)`, which traps on huge values.
- **HealthKit:** new HealthKit-backed habit types should extend
  `HealthKitSource` (label, defaultTarget, unitSuffix, symbol,
  compactValue) and add a matching branch in
  `HealthKitService.todayValue(for:)`. Report-only numbers live in
  `DayHealthMetrics` / `HealthKitService.dayMetrics(for:)`. Health is asked
  for per type with `requestAuthorization(for:)`: by the add sheet when a
  health habit is saved, and at launch only for types existing habits read.
- **SwiftData:** persist enums as `String` raw values (`frequencyRaw`,
  `sourceRaw`) with a computed property exposing the enum. New stored properties always get a default so lightweight
  migration keeps working.
- **Dark mode only:** the app is locked to `.preferredColorScheme(.dark)`.
  Do not introduce light-mode color variants (the Paper report theme is
  light on purpose; it is an image, not UI).

## Editing rules for AI agents

1. **One responsibility per file.** Views >150 lines should be split
   (e.g. `HabitDetailView` + `HabitHistoryGroup`).
2. **Match surrounding comment density.** Brief doc comments on types
   and non-obvious gestures; no rationale-for-this-change comments.
3. **Never edit `project.pbxproj` to add files**; synchronized groups
   handle that. Only touch it for build-setting / capability changes.
4. **Preserve the gesture contract** above when adding new tile-like
   surfaces.
5. **Don't create README/docs files** unless asked. CLAUDE.md is the
   sanctioned doc surface.
6. **Tests:** there is no test target yet. If adding logic that benefits
   from tests (streak math, `DayLedger`, `ReminderTiming`, HealthKit value
   mapping), surface the suggestion to the user before
   scaffolding a target. The day math already has a check: run
   `Scripts/check-day-math.sh` after touching `Date+Helpers` or
   `DayLedger`; it compares them with brute-force versions across time
   zones, including one where clocks change at midnight.
7. **Performance:** round a date to its day (`startOfDay`) as little as
   possible; each call is about a microsecond. Check many dates against
   one day with `dayRange`, step days with `previousDayStart` /
   `nextDayStart`, read `Habit.track` once per render and pass it down, and
   keep drag-driven state out of a tile's body (read it in the child that
   draws it, as `CompletionFill` does).

## Known gaps / future work

- HealthKit auto-sync only inserts a completion when today's value
  meets the target; partial progress shows on the tile's meter.
- Notifications: reminders are cadence-aware and rebuilt by
  `NotificationService.syncReminders(for:)` (launch, foreground, habit
  changes). Interval habits get rolling one-shots on due dates; timer
  taps route through `NotificationRouter`, as does the report reminder.
  Time Sensitive entitlement is intentionally unused (`.active` level
  everywhere).
