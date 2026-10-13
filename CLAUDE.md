# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repo.

## Project

**Habit Formed**: a minimalist, gesture-driven iOS habit tracker. Its look
is SpeakUp's design system, ported (deep-navy canvas, Liquid Glass plates,
colour only in data and identity, one loud CTA per screen). Inspired
functionally by the Streaks app: a small grid of tiles, each representing one
habit, with streak counts and 7-day completion dots. The signature feature is
the **daily report**: a customizable card plus text that you send to friends.

- **Platform:** iOS 26.0+ (single target, iPhone + iPad).
- **Language:** Swift 5 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Mark new pure types
  `nonisolated` (see `DayLedger`, `DailyReport`, `ReportContent`).
- **UI:** SwiftUI. UIKit only for haptics (`Extensions/Haptics.swift`), the
  share sheet (`SharePresenter`), and Messages (`MessageComposer`).
- **Persistence:** SwiftData (`@Model`): `Habit`, `HabitCompletion`,
  `ReportTemplate`. Do **not** introduce CoreData, `FileManager`, or
  `UserDefaults` for habit data. Preferences (app look, report name, report
  reminder) use `@AppStorage` with keys in `Services/AppPreferences.swift`.
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

## Folder layout

```
Habit Formed/
├── Habit_FormedApp.swift     # App entry: ModelContainer (Habit, HabitCompletion, ReportTemplate) + services
├── ContentView.swift         # Today tab: header with progress line, week strip, tile grid, undo toast
├── Models/                   # Habit, HabitCompletion, ReportTemplate (+ presets), DayLedger
├── Services/                 # HealthKit, notifications, timer, report builder/renderer, share, Messages
├── Theme/                    # Ported SpeakUp tokens: AppColors, AppLayout, AppType, AppMotion,
│                             #   GlassStyles, AppBackground, AppCanvas, CanvasLook, AppearanceEnvironment
├── Extensions/               # Haptics, Date helpers (streak math, trailing days)
└── Views/
    ├── Components/           # Ported SpeakUp components (GlassCard, GlassButton, StatTile, PageTitle, ...)
    ├── Today/                # WeekStrip, DateBrowserSheet, ArrangeHabitsSheet
    ├── AddHabit/             # AddHabitView, HabitDraft (+ HabitTemplate), form sections
    ├── History/              # ConsistencyHeatMap
    ├── Report/               # DailyReportSheet, ReportTemplateEditor, ReportCardView + styles
    ├── Settings/             # SettingsView
    ├── RootView.swift        # TabView (Today, History), mini timer banner, root sheets
    ├── HabitTileView.swift   # One grid tile
    ├── HabitDetailView.swift # Per-habit page: log + note, stats, tappable calendar, history
    ├── HistoryView.swift     # Stats, 12-week map, streaks, day-by-day log with Share
    ├── TimerView.swift       # Per-habit countdown session (auto-logs on finish)
    └── SlideToLogTrack.swift # iPhone slide-to-answer style log knob
```

## Interaction model

`RootView` hosts two tabs, each with no navigation bar (the page title is
the header):

- **Today**: `ContentView`. `PageTitle` with the browsed day's progress as
  one line ("2 of 6 done · 4 to go") and a capsule holding the perfect-day
  `StreakChip` (only once a streak exists), add (+) and Settings (gear,
  pushed). Under it the `WeekStrip` (last 7 days as dates with a completion
  dot, drawn on the canvas; tap to browse, calendar for older), then the
  "Habits" section whose header carries the "Share report" link. Keep the
  top of Today light: progress is said once, in the header line.
- **History**: `HistoryView`. Lifetime stats, a 12-week consistency map,
  per-habit streak rows (tap opens the detail sheet), and a day-by-day log
  where each day header has a Share button for that day's report.

Each habit tile responds to three gestures. Keep this consistent across
new surfaces:

| Gesture                  | Action                                |
|--------------------------|---------------------------------------|
| **Single tap**           | Open `HabitDetailView` (history + log) |
| **Slide knob right**     | Log today in place (`SlideToLogTrack`) |
| **Long-press**           | `contextMenu`: Log / Undo today, Start timer, Edit, Arrange, Delete |

The slide-to-log knob mirrors iOS's slide-to-answer: drag past ~75% and
release to log; release earlier to cancel. The track is 44pt tall. Once
logged it collapses into a "Logged" pill. Every log from the grid shows an
`UndoToast` for four seconds.

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

### Timers

Habits can carry an optional countdown timer
(`Habit.timerDurationSeconds`, set in the add sheet's Track by → Timer).
`TimerView` is a foreground session with a circular progress ring,
pause/resume/reset, and auto-logs the habit on completion (only if not
already logged today). Closing before completion does **not** log.

### Daily report

- `ReportTemplate` (SwiftData) holds one way of reporting a day: a
  `ReportStyle` layout (scoreboard, receipt, fuel, check-in, streak, clean,
  week grid),
  a `ReportTheme` canvas, an accent, words (title, message, footer, caption)
  and toggles (which habits, unfinished, streaks, 7-day dots, notes,
  perfect-day streak, calories, activity). `ReportPreset.all` seeds one
  template per preset the first time the sheet opens.
- Words accept tokens (`ReportToken.all`: `{name}`, `{done}`, `{total}`,
  `{checklist}`, `{eaten}`, `{net}`...), expanded by `ReportText` at send
  time.
- `DailyReportBuilder` turns habits + a template into a `DailyReport` value;
  `ReportCardView` draws it at a fixed 390pt width with painted fills only
  (no glass: `ImageRenderer` cannot draw it); `ReportCardRenderer` renders
  it (scale 2 for previews, 3 for sending).
- `DailyReportSheet` previews the exact output in three kinds (Card, Story
  for a 9:16 Instagram or Snapchat story via `ReportStoryView`, or Text),
  then Save / Copy / Text it (`MessageComposer`, Messages with the image
  attached) / Share (`SharePresenter`). The card prints the reporter's name
  (`AppPreferences.reporterName`) so a forwarded card still says whose day
  it was. Calories eaten come from Apple Health and can be typed over before
  sending.
- An optional evening nudge (`report-reminder`) opens today's report.

## Conventions

The design system is SpeakUp's; when in doubt, match
`../SpeakUp-App/docs/features/ui-design-system.md`.

- **Surfaces:** cards are `GlassCard` / `.glassCard(cornerRadius:tint:)`
  (Liquid Glass). Never stack glass on glass: inside a card use
  `.plateChrome(in:)`, `.inputWell()`, or `.controlChrome(in:)` (which
  branches on `\.isOnGlass`). Radii and padding come from `AppLayout`
  (card 20 / 16, tile 16 / 12, well 12).
- **Colour:** only `AppColors`. Identity tints stay at 0.06 on a tile
  (`AppColors.identityTint`) and 0.10 when featured or done
  (`featuredTint`). A habit's glyph uses `color.glyphTone` (lifted toward
  white). Habit colors come from `AppColors.tilePalette`.
- **Glyphs:** bare, never on a disc or plate (`IconChip`, `RowGlyph`).
- **Buttons:** `GlassButton` (primary is solid white, one per screen);
  words-only buttons use `.buttonStyle(.textLink)`. Selected chips and
  segments are solid white with `AppColors.inkOnLight` text.
- **Type:** text styles that scale (`.subheadline.weight(.semibold)` etc.);
  numerals use `.displayNumeral`, `.ringNumeral`, `.metricValue`,
  `.statValue`. Small caps labels use `.eyebrowStyle()`; never hand-roll
  uppercase + tracking.
- **Sections:** `GlassSection("Title", meta:)` with a sentence-case header.
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
  `DayHealthMetrics` / `HealthKitService.dayMetrics(for:)`.
- **SwiftData:** persist enums as `String` raw values (`frequencyRaw`,
  `sourceRaw`, `styleRaw`, `themeRaw`) with a computed property exposing
  the enum. New stored properties always get a default so lightweight
  migration keeps working.
- **Dark mode only:** the app is locked to `.preferredColorScheme(.dark)`.
  Do not introduce light-mode color variants (the Clean and Receipt report
  cards are paper on purpose; they are images, not UI).

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
   from tests (streak math, `DayLedger`, `ReportText` token expansion,
   HealthKit value mapping), surface the suggestion to the user before
   scaffolding a target.

## Known gaps / future work

- App icon PNG is not yet present in
  `Assets.xcassets/AppIcon.appiconset/` (the `Contents.json` slot is
  defined; a 1024×1024 image needs to be dropped in).
- HealthKit auto-sync only inserts a completion when today's value
  meets the target; partial progress shows on the tile's meter.
- Notifications: reminders are cadence-aware and rebuilt by
  `NotificationService.syncReminders(for:)` (launch, foreground, habit
  changes). Interval habits get rolling one-shots on due dates; timer
  taps route through `NotificationRouter`, as does the report reminder.
  Time Sensitive entitlement is intentionally unused (`.active` level
  everywhere).
- The report card's barcode is decorative, not scannable.
