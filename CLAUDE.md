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
├── ContentView.swift         # Today, the root page: month control, week strip, the habits, undo toast
├── Models/                   # Habit, HabitCompletion, DayLedger, ReminderTiming, ReminderSuggestion,
│                             #   HabitGuess, ReportOptions (+ ReportTheme, ReportScope, ReportLayout, YearLayout)
├── Services/                 # HealthKit, notifications, timer, widget sync, day, week (WeeklyRecap) and
│                             #   year (YearReport) builders, renderer (+ ReportPosterView), share, Messages,
│                             #   HabitInsights, OnDeviceModel, ReportHeadline
├── Intents/                  # Siri: HabitEntity, LogHabitTodayIntent, AddHabitIntent, TodayStatusIntent,
│                             #   HabitShortcuts
├── Theme/                    # Ported SpeakUp tokens: AppColors, AppLayout, AppType, AppMotion,
│                             #   GlassStyles, AppBackground, AppCanvas, CanvasLook, AppearanceEnvironment
├── Extensions/               # Haptics, Date helpers (streak math, trailing days)
└── Views/
    ├── Components/           # Ported SpeakUp components (GlassCard, GlassButton, PageTitle, ...) and the
│                             #   app's own: Panel, Chips (ChoiceChip, ToggleChip), SwatchRail
    ├── Today/                # WeekStrip, TodayHabitList, DateBrowserSheet, ArrangeHabitsSheet
    ├── AddHabit/             # AddHabitView, HabitDraft (+ HabitTemplate), form sections (ideas, look, how you log it,
│                             #   how often), HabitReminderSection, asked as plain questions with chips
    ├── History/              # HistoryHero, PatternsSection, ConsistencyHeatMap (+ legend), DayRow
    ├── Report/               # ReportSheet (Day, Week, Year; the send page or the studio), ReportSheetFields,
    │                         #   ReportSheetParts (preview, stage, thumbnail), ReportSheetControls (scope picker,
    │                         #   theme row, edit button, send bar), ReportStudio (+ ReportLayoutTools,
    │                         #   ReportCardTools: Content and Style), MacroFieldsRow,
    │                         #   ReportCardChrome (palette, header, note, regions, ground),
    │                         #   ReportCardView (+ ReportCardLayouts: Grid, Focus; ReportLedger, ReportTimeline,
    │                         #   ReportMinimal, ReportWeekBoard, ReportBubbles, ReportHealthSection,
    │                         #   ReportRingLayouts: the day ring, Rings, Orbit; ReportSundial (+ Key), ReportGarden,
    │                         #   and the ones with a look of their own: ReportFrontPage, ReportReceipt,
    │                         #   ReportPunchCard, ReportConstellation, ReportStamps),
    │                         #   WeeklyRecapCardView (+ Grid), YearReportCardView (+ YearReportDays, YearReportHabits)
    ├── Settings/             # SettingsView, LayoutPicker (tiles and rows as `SketchPicker` pictures)
    ├── RootView.swift        # One NavigationStack (no tab bar), mini timer banner, timer and report sheets
    ├── HabitTileView.swift   # One grid tile
    ├── HabitRowView.swift    # One capsule row (the Rows layout), with RowTimerButton
    ├── HabitActions.swift    # HabitActions + HabitContextMenu, shared by tiles, rows, done chips
    ├── HabitStatusLine.swift # Streak and schedule line, shared by tiles and rows
    ├── HabitDetailView.swift # Per-habit page: streak hero, tappable history calendar, log + note, recent logs;
    │                         #   Edit and Delete in its top bar's More menu
    ├── HabitHealthReading.swift # A health habit's reading on its page, where the log button would be
    ├── HistoryView.swift     # One page: hero, patterns, 12-week map, streaks, days that open in place
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

`RootView` hosts one `NavigationStack` and no tab bar, so nothing sits over
the habits. Today is its root page, with no navigation bar; a new habit,
History and Settings are pushed from Today's top row, and Edit habit from a
habit's menu or page. No page shows the system bar:
pushed from a bar-less Today it animated in on its own track, its back
button and title trailing the page. Every pushed page wears
`pageTopBar(_:)` instead (`PageHeader.swift`): a back button in header
glass, the title, an optional trailing control, drawn as part of the page
so it moves with it, and a hook (`SwipeBackHook`) that keeps swiping back
working with the bar hidden, from the edge or anywhere on the page (a swipe
that starts on a sideways rail scrolls the rail). A page with something to
lose passes `back:` (the add and edit page while it has changes): back asks
first and swiping back is off.

- **Today**: `ContentView`. No page title: the top row is the month
  ("October ⌄" in `.title` bold, as big as fits beside the capsule, its
  chevron in the look's accent; it opens the calendar) and a capsule holding
  Share report (the day shown, a sheet), then the pages it pushes: add (+),
  History (clock) and Settings (gear). The
  calendar is a full-height sheet (a shorter one floats off the screen's
  edges on iOS 26). Right under it the `WeekStrip` is the date control: one
  row of 7 rings drawn on the canvas, each holding its weekday and date and
  filling as that day's habits are logged (closed and green on a perfect
  day). The selected day sits on a soft circle of glass, never solid
  white: one circle under the row that glides to the day tapped
  (`AppMotion.slide`; a glass container would draw it over the letters),
  while the grid lands on the new day at once. Strip taps only change the selected day; the strip itself moves
  only when the calendar picks an older day (`stripAnchor`). The habits
  follow with no title or count over them: the strip's ring is the day's
  progress, said once. Under the grid sits a "Today" link while browsing
  another day, and once today is perfect a solid "Share today's report",
  the screen's one primary button.
  Every habit shows, as tiles or rows (`TodayLayout`, picked
  in Settings), and each stays in place: **done is the tile or row filled
  with its habit's color** (`CompletionFill`), so a finished day is a grid
  of filled squares and needs no other line to say so. Done means logged on
  the day shown, the ledger's `.done`, and one `isDone` drives the fill,
  the white glyph, the featured tint and the spoken state, so a tile always
  agrees with the week strip's ring and its own pill; a weekly
  habit's week is its status line's to say ("2 of 3 this week").
  A tile is a watermark: its glyph at 104pt running off the top trailing
  corner (`glyphTone` at 12%, white at 12% on the fill), the name and the
  `HabitStatusLine` at the top, and at the bottom the way to log, every
  kind of it a 44pt pill (the slide, a timer's play pill, a health meter;
  on a past day always the slide). Done today, the pill says when ("Logged 9:41 AM",
  `SlideToLogTrack.loggedLabel`) beside the white check. The status line leads with the streak's
  number ("3 days · 1 of 5 this week"), rounded, medium weight and a step
  under the name, and is one numeral tall even without one, so tiles in a
  row stay level. The name leads and the line sits back: the number in
  soft white, the unit softer, the schedule gray unless it asks for
  attention (then the habit's `glyphTone`). A row keeps
  the same line at caption size and is a capsule: its corners are the
  slide's pill plus the row's 10pt inset, so the two curves nest, and its
  short slide has no words (a tile's says "Slide to log").
- **History**: `HistoryView`, pushed from the clock, one page with no picker. `HistoryHero` is
  the perfect-day streak as one big number, with the best and the last
  seven days under it and a "Weekly recap" button. Then "Patterns" (up to three
  lines `HabitInsights` found in the last eight weeks, plus an Apple
  Intelligence tip when the model is there; hidden until two weeks of days
  exist and something holds). Then the 12-week map with its
  legend, per-habit streak rows (tap opens the habit's page), and the days:
  each a `DayRow` (name, logged glyphs, "2 of 3") that opens in place to
  list its logs (long-press one to remove it) and a "Share report" row.
- **Settings**: pushed from the gear. Today (layout as two small pictures,
  arrange, log sound, the Siri phrase with one of your habits), Reports
  (Report style, which holds your name too, daily reminder with its time,
  weekly recap)
  and Look (canvas rail, plain ones first after Classic, and glass). No captions except where the words are the
  content (the Siri phrases); few-way choices are chips in their row.

The rule across screens: say each fact once, keep captions for what is not
obvious, paint only the selected choice in a grid, and prefer one line of
text over another card.

Each habit tile responds to four gestures, and so do rows. They all take one `HabitActions` and share
`HabitContextMenu`; keep it that way for new surfaces:

| Gesture                  | Action                                |
|--------------------------|---------------------------------------|
| **Single tap**           | Open `HabitDetailView` (history + log) |
| **Slide knob right**     | Log today in place (`SlideToLogTrack`) |
| **Long-press**           | `contextMenu`: Log / Undo today, Start timer, Edit, Arrange (before iOS 27), Delete |
| **Long-press and drag**  | Move it in Today's order (iOS 27: `reorderable()` in `TodayHabitList`; the menu gives way as it lifts) |

Every order change goes through `Habit.move(_:from:to:in:)`, which writes
only the places that changed; Settings → Arrange habits uses it too and is
the way to reorder before iOS 27. While a habit is held its card is
`isLifted` and `glassCard` paints `AppColors.liftedPlate` under its tint
instead of glass: the lifted copy is drawn from the card left in the grid,
so glass would keep showing the spot it left.

The slide-to-log knob mirrors iOS's slide-to-answer. As it travels, the
habit's color pours out of it at half strength (a circle centred on the
knob that reaches the tile's far corner as the knob arrives; once the log
lands a second coat, the full color, pours out of the check at once,
`CompletionFill.sync`) and its chevron winds clockwise
into clock hands showing the time right now (the knob's disc is the face),
holds there, then folds into a check (`ClockGlyph`: one stroke, a corner
and two legs moving between poses); at ~75% the check is whole and it
arms (a click and a small pop), and letting go logs. The travel is felt:
`Haptics.grab` as the knob is taken, `slideStep` every 14pt, firming up
toward the arm point, `arm` there (`disarm` pulling back), `success` on the
log. The knob takes a touch up to 10pt off its disc, so a thumb a little
wide still catches it. Holding the knob keeps
the long-press menu shut, so a pause mid-slide never opens it. Release earlier to cancel; a flick from halfway logs too. The
surface owns the knob's `progress`, so an undo plays it all backwards. The
track is 44pt tall with the 36pt knob inset in it; its gray pill is what
is left to slide, shrinking behind the knob over the fill. Flat, no
shadows: the knob is a disc a step lighter than the habit's color, so it
stays distinct on the fill. Done, the channel and
the knob melt into the fill and only the white check stays. Every log from
the grid shows an `UndoToast` for four seconds; the log that finishes a
perfect day turns it into "Perfect day" for six, and the report button
under the grid takes it from there. A swipe up or to either side sends the
toast off at once, like a notification banner, and dragging it holds its
time. It sits over the whole page, not the scroll view, so taps on it
never fall through to the header.

Logs from Today chime through `ContentView.logToday`, a pentatonic step
higher as the day fills (`SoundEffects.logChime(progress:)`), so callers
there play the haptic only. The perfect day adds `SoundEffects.perfectDay`
(a rolled chord on its own player) and `Haptics.celebrate` over the
confetti. Taking back your own log is `Haptics.undo`, not a warning.

When the grid shows a **past day**, every tile and row logs it with the
slide, whatever its kind (a timer cannot run for yesterday), and once done
says "Logged" with no control to tap. Taking a past day's log back is the
long-press menu's "Remove this day's log", with the toast to undo it, so a
stray tap never logs or unlogs a day. The
habit page's calendar stays the deliberate way to set any day.

All log writes go through `Habit.log(on:in:)` and `Habit.removeLog(on:in:)`
so a day never holds two completions. Logs made with no window open (Siri,
a reminder's "Log it") go through `HabitLifecycle.logToday`, which also
refreshes the widget and rebuilds reminders so one due later today stays
quiet. Deleting a habit goes through
`HabitLifecycle.delete` (stops its timer and reminders first).

### Day ledger

`Models/DayLedger.swift` is the one source for "X of Y done", the week strip
rings, the perfect-day streak and the report's counts. Per habit and day a
`DayStatus` is `done`, `open` (today, not yet), `missed` (past day),
`flexible` (weekly habits on an unlogged day: never a miss), or `resting`
(interval countdown running, or before the habit existed). Only done, open
and missed count toward the total. A perfect day logged everything expected;
days that expected nothing are skipped by the streak.

### Adding a habit

A new habit fills itself in from its name as it is typed
(`HabitGuess`, words and patterns, no model): a glyph for the activity
("Walk the dog" a paw, "Water the plants" a leaf), a timer for a length
("Read 20 min"), Apple Health for a metric ("10k steps", "Sleep 8 hours",
"Run 5k"), and the schedule ("3x a week", "every 3 days"; days of the week,
"Gym Mon Wed Fri" or "on weekends", are that many a week and become the
reminder's days, a short "Sun" or "Wed" only in a list or after "on" or
"every"). The glyph and the plan (`HabitDraft.Plan`: how and how often, and
the reminder's days) each follow the name only
while they still hold what it last set (`HabitDraft.follow`), so a chip the
person taps, or an idea, makes that part theirs; editing never moves them.
A length or count outside the chips joins them as the lit one.

So Return adds a new habit. "How do you log it?" (check off, timer, Apple
Health) stays in view, since it is what makes habits different; how often
and the reminder fold into one line under it (`HabitDraft.summary`: "Every
day, no reminder") that opens them in place. Editing shows everything.

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

A daily or weekly reminder can keep to picked weekdays
(`Habit.reminderWeekdays`, `ReminderDaysPicker`: a letter per day in the
week's order); none picked is every day, and a weekly one still goes quiet
once the week's target is met. Picked days are always one alert per day
(`pickedReminderDays`), so they never fall back to the daily alert.
Interval habits ignore them. Editing a weekly habit with no days picked
offers the days it is usually logged on (`ReminderTiming.usualWeekdays`:
as many as its target, two logs each at least) with a "Use" link, never
set on their own. A reminder never prints this week's count: a repeating
alert would carry it into later weeks, so a weekly one says its goal ("3
times a week"). A reminder switch that is on while iOS has notifications
off shows `NotificationsOffRow`, which opens the app's notification
settings.

A new habit gets a suggested time while its name is typed
(`ReminderSuggestion`): a word in the name ("meditate" mornings, "read"
evenings, "at night") or, when another habit is usually logged near then,
30 minutes before it. `HabitReminderSection` shows it with its reason in
one line ("9:30 PM, evenings suit reading" while off; only the reason once
on, since the Time row shows the time), adopts it when the switch turns on,
and follows the name until the picker moves. The suggestion lives in view
state, never in `HabitDraft`, so an untouched form stays clean; editing a
habit never moves a set time. The habit page says the reminder in one line
("Reminds you at 9:35 AM, before your usual 10:05 AM").

### Widgets

The widget never opens SwiftData. `WidgetSync` (app side) writes a
`WidgetSnapshot` (today's page plus tomorrow's, so the widget flips at
midnight on its own) to the App Group whenever `WidgetSync.signature`
changes, and reloads timelines only when the snapshot differs. Tapping the
small widget opens today's report (`WidgetLink.report`, handled in
`RootView.onOpenURL`; the scheme is registered in
`Habit-Formed-Info.plist`). The medium
widget's log button runs `LogHabitIntent`, which queues a
`PendingWidgetLog` and marks the habit done in the snapshot. It is a
`LiveActivityIntent`, so it runs in the app's process (launched in the
background when closed), where `LogHabitIntent.writeInApp`, set at launch,
writes the real log (keeping the tap time as `loggedAt`) and rebuilds
reminders at once (`HabitLifecycle.writeWidgetLogs`), so one due later
today stays quiet. A queue left behind is written on launch or on returning
to the foreground. Always apply pending logs before writing a snapshot.

### Timers

Habits can carry an optional countdown timer
(`Habit.timerDurationSeconds`, set in the add page's "How do you log it?" → Timer).
`TimerView` is a foreground session with a circular progress ring,
pause/resume/reset, and auto-logs the habit on completion (only if not
already logged today). Closing before completion does **not** log.

### Reports

Keep it simple: one sheet, one card at a time, everything on by default,
switches to take things out. No templates or placeholder tokens.

- `ReportSheet` is the one way to send: Day, Week or Year
  (`ReportScope`, `ReportScopePicker`: one glass capsule pinned under the
  title, the picked one a solid white pill that glides) over the card as
  it will be sent, then one panel of fields (calories eaten while Calories
  is on, protein, carbs and fat while Macros is on, the day card only; then
  this card's note), with Text it (`MessageComposer`, Messages with the
  image attached) and Share (`SharePresenter`; Save and Copy live in the
  share sheet) pinned at the foot (`safeAreaBar`), so they never scroll out
  of reach. Today's Share report opens it on Day, History's Weekly recap,
  the Sunday nudge and `WidgetLink.recap` on Week (`RootSheet.recap`); the
  week ends and the year runs up to the sheet's day. Every card sends alone,
  with no text typed under it, and prints the reporter's name
  (`AppPreferences.reporterName`) so a forwarded card still says whose it
  was.
- Edit, or a tap on the card, opens the studio (`ReportStudio`): the whole
  card on a stage (`ReportStage`, scaled to fit both ways) over a dock of
  tools picked with chips, Layout (the day's layouts as a rail of live
  thumbnails of your own card, `ReportLayoutGallery`, with the Count chips
  under it; Pixels or Months for the year; the week has one layout),
  Content (name, this card's note, habits, details, Health, as
  `ToggleChip` bands) and Style (background rail, accent dots, type, each
  only where the card shows it). The card is edited on itself: its parts
  are `reportRegion`s, outlined in dashes in the studio only, and a tap on
  one opens its tools (the habits Layout, the name, Health and note
  Content, the ground Style). `reportRegionTap` is set only by the studio,
  so the image sent and the send page never react. Settings → Report
  style opens the studio alone (`ReportSheet(isPreset: true)`, nothing to
  send). The sheet sends nothing it has not shown: the poster is the
  preview too.
- `ReportOptions` is the whole configuration: a `ReportTheme` (App look by
  default, which paints whatever `AppCanvas` the app wears via
  `ReportOptions.appLook`; or a canvas, the plain ones first; or a paper:
  Paper, Stone, Cloud), a `ReportLayout`, offered in `ReportLayout.gallery`
  order, the plain ones first: List, Ledger (a table: today's mark, the run
  and the last seven days in columns under eyebrow headings, a total under
  a double rule), Minimal (the count set large, the habits in two columns,
  a dot each), Timeline (each log at its time on a line down the leading
  edge, then still open, also done and off today), Grid like Today, Week (a
  board of the last seven days), Rings (the same week as a ring per habit
  from the outside in, seven arcs each, named beside it in ring order),
  Focus (one big ring and a centred strip of glyphs), Orbit (the day's ring
  with each habit a circle on an orbit round it, bigger for a run of a week
  or more), Sundial (a 24-hour dial, midnight at the top: logs made within
  40 minutes of each other gather into one numbered bead at the first's
  time, `SundialMoment`, shared in wedges, named in `ReportSundialKey`
  under the dial with what is open, done untimed and off; the night's
  sleep, `DayHealthMetrics.sleepSpan`, the longest stretch so a nap stays
  out, and workouts, `workoutSpans`, as thin rim bands while the card shows
  them; a hand at now on today's), Bubbles (a honeycomb of circles that fill
  when done; rows of one or three take turns with rows of two,
  `ReportBubbles.rowPlan`, so no row lands on the one above), Garden (a
  plant per habit in beds of up to five, a leaf per step of its run while
  streaks show, four at most, a bloom once done, a bud while open filled to
  a Health habit's `progress`), then the things of their own: Front page
  ("The Daily Habit", its headline and the line under it written from the
  numbers by `ReportHeadline`, no model; done and still open in two
  columns, or one side across both when the other is empty; "By the
  numbers"; a ticker of the five longest runs), Receipt (a torn slip in
  monospaced capitals lying on the card's background, habits on dotted
  leaders, Health numbers as line items, a barcode), Punch card (a kraft
  card on a dark table, a hole punched through per day logged in the last
  week), Stamps (a stamp per habit on an airmail envelope, postmarked once
  done, Health as a customs declaration) and Constellation (a night sky,
  done stars joined in the order logged, `Item.loggedAt`, dashed on through
  the dark ones, three to a row winding back and forth). Front page,
  Receipt, Punch card, Stamps and Constellation are `ReportLayout.ownsLook`:
  their own paper, ink and type from `AppColors` (Report papers) and iOS's
  own faces (Didot, Courier, Futura, Baskerville, Bodoni), so the studio
  hides Accent and Type for them and Background for all but the receipt
  (`showsBackground`; its store mark takes the accent); they print Health
  as lines (`DayHealthMetrics.lines(showing:)`). Then `ReportRing` for the
  layouts with a count in the header's corner (`showsRing`: Big ring, Small
  ring, or Number), an accent (empty follows the theme's
  `CanvasLook.accent`, or a palette hex), a `ReportFont` (Default, Rounded,
  Serif, Mono), the year's `YearLayout`, hidden habits, switches for each
  habit's streak (the card prints no perfect-day streak; History keeps
  that), habit notes (List, Timeline: `showsHabitNotes`) and the last 7
  days (List, Ledger: `showsWeekDots`), and the Apple Health numbers
  (`ReportMetric`: steps, exercise, sleep, mindful, calories in vs out,
  macros), one chip each so what is picked is exactly what shows. All in
  `@AppStorage` (metrics as one comma-joined `report.metrics`, defaulting
  to what the old Calories and Activity switches had on); the note is for
  one card only.
- Every card is built on `ReportCardChrome`: `ReportPalette` (ink on canvas
  or paper), `ReportCardHeader` (name, date and, on a perfect day, a green
  "Perfect day"; the count at its trailing edge), `ReportNote`,
  `reportCardFrame` (390pt, inset, ground, type) and `reportInk` (Dynamic
  Type pinned). A card says each fact once: no verdict or percent beside
  the count, no app wordmark, no captions explaining the drawing. Every
  day ring is `ReportDayRing`: an arc per expected habit, in its colour once
  done, done ones first, so a perfect day closes in every colour; its
  centre is `DailyReport.countText` ("3/5", or "Rest" on a day that asked
  nothing). Health is at most two wells (`ReportHealthSection`: activity in
  up to four columns, with exercise split over the day's workouts,
  `DayHealthMetrics.exerciseKinds`, at most three parts; then food,
  calories over the macros), and a number Health lacks is left out, never
  "n/a". No text on a card under 11pt.
- `DailyReportBuilder` turns habits + options into a `DailyReport` value,
  `WeeklyRecapBuilder` a `WeeklyRecap`, `YearReportBuilder` a `YearReport`;
  `ReportCardView`, `WeeklyRecapCardView` and `YearReportCardView` draw them
  with painted fills only (no glass: `ImageRenderer` cannot draw it).
  `ReportPosterView` lays a card on its backdrop (`ReportBackdrop`: its
  canvas or paper, or the colour under a layout with paper of its own)
  never taller than 4:5 (`ReportCardRenderer.maxAspect`), the tallest
  Messages and Instagram show whole: a taller card gets the backdrop
  widened beside it instead of anything cut, and the backdrop is painted
  edge to edge so a widened canvas has no seam (`reportPaintsCanvas`). The
  send page shows that poster live (`ReportPreview`);
  `ReportCardRenderer` draws it at 3x, opaque, only when it is sent. Keep a
  5-habit card without Health near 390 by 487 so it is not shrunk.
- An optional daily reminder (`report-reminder`) opens today's report.
  Turning it on sets it 30 minutes after the day's usual last log
  (`ReminderTiming.reminder(afterTypical:)`), with that reason as the
  row's caption; the time stays the person's to change.

### Weekly recap and year

The week's card is the same idea for the last seven days:
`WeeklyRecapBuilder` (perfect days against the week before, each habit's
seven `DayStatus` squares, the longest streak and the habit that climbed
most) and `WeeklyRecapCardView`, each number over the habit it belongs to.
An optional Sunday 7 PM nudge (`recap-reminder`, switched on in Settings)
opens it. The year's card runs from January 1 to the sheet's day:
`YearReportBuilder` walks those days once (`DayLedger.summaries`) for
perfect days, logs, the best run of perfect days, each habit's rate (weekly
habits by the weeks they met) and best run, the best month and the
strongest weekday, and `YearReportCardView` draws the days as Pixels (a row
per month, a square per day) or Months (twelve small calendars). Both share
the day card's theme, accent, type, hidden habits and name.

### Siri and Apple Intelligence

`Intents/` holds the app's App Intents: `LogHabitTodayIntent` ("Log Read in
Habit Formed") logs today without opening the app and replies with the
day's count, `AddHabitIntent` ("Add a habit in Habit Formed") asks for a
name and makes the habit from it with `HabitGuess`, as the add page does
("Gym 3 times a week" is Gym, 3 a week), and `TodayStatusIntent` ("What's
left in Habit Formed") lists what is open. `HabitEntity` matches a spoken name loosely. Siri learns habit
names only from `HabitShortcuts.updateAppShortcutParameters()`, which Today
calls when the titles change. Intents reach the store through
`Habit_FormedApp.sharedModelContainer`. The widget's `LogHabitIntent` is
separate (hidden, App Group queue).

The on-device model (`Services/OnDeviceModel.swift`, FoundationModels) only
words what the app has already worked out: the math decides, the model
phrases. Every caller keeps a plain sentence for when it returns nil (most
devices), never calls it from `body`, and checks the reply (length, no
numbers it was not given) before showing it. Today it rewords a reminder
suggestion's reason and writes History's one tip, cached a day per set of
facts (`AppPreferences.insightsTip`).

## Conventions

The design system is SpeakUp's; when in doubt, match
`../SpeakUp-App/docs/features/ui-design-system.md`.

- **Surfaces:** cards are `GlassCard` / `.glassCard(cornerRadius:tint:)`
  (Liquid Glass). Never stack glass on glass: inside a card use
  `.plateChrome(in:)`, `.inputWell()`, or `.controlChrome(in:)` (which
  branches on `\.isOnGlass`). Radii and padding come from `AppLayout`
  (card 20 / 16, tile 16 / 12, well 12); a `Panel` uses the card radius, Today's habit tiles the tile radius and its rows the slide's pill plus their inset (a capsule). Groups of rows (History,
  Settings, the report sheet and the add page) sit on a `Panel`, one pane of glass
  with hairlines. Chips use `controlChrome`, so a row of them on the canvas
  is interactive glass (wrap it in a `GlassEffectContainer`) and inside a
  panel they are plates. Alignment: text outside a card (page titles,
  section headers, the History hero) sits on the card's edge, and
  everything inside a card or tile sits `AppLayout.tilePadding` (14) in. The material is glass; nothing draws its own
  bevel, gradient or glow. Names: the daily card is the "report", the
  weekly one the "recap".
- **Colour:** only `AppColors`, plus the app look's accent
  (`CanvasLook.accent`, read from `\.appCanvas`) for switches, the week
  strip's rings and the calendar, so Ember runs copper and Forest sage. Identity tints stay at 0.06 on a tile
  (`AppColors.identityTint`) and 0.10 when featured (`featuredTint`), laid
  over Settings → Look → Glass's white lift (`AppColors.glassTint`), so a
  habit's glass follows Light and Dark like every untinted pane. Every
  `glassEffect` takes its tint from that setting; none is plain `.regular`. The
  one solid use of a habit's color is Today's done fill, with the glyph and
  its marks (status line, meter) turning white on it. A habit's glyph otherwise uses `color.glyphTone`
  (lifted toward white), faded to 12% as a tile's watermark. Habit colors come from `AppColors.tilePalette`;
  a new habit starts in the least-worn one (`HabitDraft.freshColor`).
- **Glyphs:** bare, never on a disc or plate (`IconChip`, `RowGlyph`).
- **Buttons:** `GlassButton` (primary is solid white, one per screen);
  words-only buttons use `.buttonStyle(.textLink)`. One icon rule: an
  action's glyph leads its words (`GlassButton`, `Label`, `HeaderLinkLabel`),
  and only a disclosure chevron trails them, turning 180° when it opens. Selected chips and
  segments are solid white with `AppColors.inkOnLight` text. The week
  strip is the exception: its selected day is a soft circle of glass.
- **Type:** text styles that scale (`.subheadline.weight(.semibold)` etc.);
  numerals use `.displayNumeral`, `.ringNumeral`, `.metricValue`,
  `.statValue`. Small caps labels use `.eyebrowStyle()`; never hand-roll
  uppercase + tracking.
- **Sections:** `GlassSection("Title", meta:)` with a sentence-case header;
  `detail:` puts one fact right after the title.
- **Pages:** `PageScrollView` + `.pageContentInsets()` on every page; sheets
  close with `Button(role: .close)` top leading (no haptic), and a Done
  that commits is `Button(role: .confirm)`; deletes confirm with an
  `.alert("Delete this X?")` (a log: "Remove this log?", `confirmsLogRemoval`), and stopping a running timer always asks
  "Stop the timer for X?". A habit's page is pushed on the stack
  (`navigationDestination(item:)`), so it opens fast and swipes back from
  the edge; the timer zooms out of the mini banner (`zoomSource` +
  `.navigationTransition(.zoom)`).
- **Motion:** `AppMotion` tokens and `.motion(_:value:)`, or
  `withMotion(_:_:)` for a change made in an action; both go still under
  Reduce Motion (never call `withAnimation` directly). Numbers that change
  roll (`.contentTransition(.numericText())`; a countdown passes
  `countsDown: true`), a glyph that changes state morphs (`symbolSwap`), a
  running timer's waveform moves (`.symbolEffect(.variableColor)`), and a
  check that lands bounces once (`.symbolEffect(.bounce, value:)`). None
  of it inside the report or recap cards, which `ImageRenderer` draws.
- **Haptics:** route every tactile moment through `Haptics.*`; taking a
  log back is `Haptics.undo` wherever it happens. Don't
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
  Keep UI copy plain and short; captions end without a period, and two
  facts in one line join with a comma. Tiles and rows say the same thing
  the same way ("Log", "Next log in 3 days", "10 min").
- **Numbers:** convert user-typed or HealthKit doubles with
  `Double.safeRounded`, never `Int(x)`, which traps on huge values. Time
  reads as hours and minutes ("7h 40m", `Double.minutesAsDuration`), never
  as decimal hours ("7.7h").
- **HealthKit:** new HealthKit-backed habit types should extend
  `HealthKitSource` (label, defaultTarget, unitSuffix, symbol,
  compactValue) and add a matching branch in
  `HealthKitService.reading(for:from:to:)`. Report-only numbers live in
  `DayHealthMetrics` / `HealthKitService.dayMetrics(for:)`. Health is asked
  for per type with `requestAuthorization(for:)`: by the add page when a
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
   zones, including one where clocks change at midnight. Likewise run
   `Scripts/check-reminder-suggestion.sh` after touching
   `ReminderSuggestion`, `Scripts/check-insights.sh` after touching
   `HabitInsights`, and `Scripts/check-habit-guess.sh` after touching
   `HabitGuess`.
7. **Performance:** round a date to its day (`startOfDay`) as little as
   possible; each call is about a microsecond. Check many dates against
   one day with `dayRange`, step days with `previousDayStart` /
   `nextDayStart`, read `Habit.track` once per render and pass it down, and
   keep drag-driven state out of a tile's body (read it in the child that
   draws it, as `CompletionFill` does).

## Known gaps / future work

- HealthKit auto-sync only inserts a completion when today's value
  meets the target; partial progress shows on the tile's meter. Each sync
  reads for the day it runs on (`liveValues` start empty each day, so a
  total held over midnight never checks off the next day), and takes back
  a log sync wrote that a fresh total for its day falls short of; once a
  launch it checks the last 30 days the same way. A log by hand records
  the goal itself and is never taken back. Today is Health's to check
  off: a health habit's page shows its reading where the log button would
  be, its long-press menu has no "Log today", and Siri declines too. The
  page's calendar stays the deliberate way to set any day by hand.
- Notifications: reminders are cadence-aware and rebuilt by
  `NotificationService.syncReminders(for:)` (launch, foreground, habit
  changes). Interval habits get rolling one-shots on due dates; timer
  taps route through `NotificationRouter`, as does the report reminder.
  Time Sensitive entitlement is intentionally unused (`.active` level
  everywhere).
