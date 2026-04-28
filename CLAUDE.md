# CLAUDE.md

Guidance for Claude Code (and other AI agents) working in this repo.

## Project

**Habit Formed** — a minimalist, gesture-driven iOS habit tracker. Aesthetic
borrows from the SpeakUp app (deep-navy background, ultra-thin glass
materials, oversized rounded typography). Inspired functionally by the
Streaks app: a small grid of tiles, each representing one habit, with
streak counts and 7-day completion dots.

- **Platform:** iOS 26.0+ (single target, iPhone + iPad).
- **Language:** Swift 5 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- **UI:** SwiftUI only — no UIKit views (UIKit is used solely for
  `UIImpactFeedbackGenerator` in `Extensions/Haptics.swift`).
- **Persistence:** SwiftData (`@Model`). Do **not** introduce CoreData,
  `FileManager`, or `UserDefaults` for habit data.
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
`Habit Formed/` folder is picked up automatically — no `pbxproj` edits
are needed when adding new Swift files.

## Folder layout

```
Habit Formed/
├── Habit_FormedApp.swift     # App entry — wires ModelContainer + HealthKitService, mounts RootView
├── ContentView.swift         # Today-tab grid of HabitTileView + sheet routing (HabitSheet enum)
├── Habit_Formed.entitlements # HealthKit capability
├── Models/                   # @Model types (Habit, HabitCompletion)
├── Services/                 # HealthKitService
├── Theme/                    # AppColors, AppBackground, GlassStyles (glass card modifier)
├── Extensions/               # Haptics, Date helpers (streak math, trailing days)
├── Views/                    # All SwiftUI views (one View per file when reasonable)
│   ├── RootView.swift        # TabView host: Today + History
│   ├── HistoryView.swift     # Cross-habit log feed + lifetime stats
│   ├── TimerView.swift       # Per-habit countdown sheet (auto-logs on finish)
│   └── SlideToLogTrack.swift # iPhone slide-to-answer style log knob
└── Assets.xcassets/          # AppIcon (universal iOS), AccentColor
```

## Interaction model (the spec, in one place)

The app is a two-tab `TabView` (`RootView`):

- **Today** — `ContentView` grid of `HabitTileView`.
- **History** — `HistoryView` lifetime stats + day-grouped completion feed.

Each habit tile responds to three gestures. Keep this consistent across
new surfaces:

| Gesture                  | Action                                |
|--------------------------|---------------------------------------|
| **Single tap**           | Open `HabitDetailView` (history + log) |
| **Slide knob right**     | Log a completion in place (`SlideToLogTrack`) |
| **Long-press**           | `contextMenu` → Edit / Log Today / Delete |

The slide-to-log knob mirrors iOS's slide-to-answer affordance: drag
past ~75% of the track and release to log; release earlier to cancel.
Once the habit is logged for the day the track collapses into a
"LOGGED TODAY" pill.

The detail view (`HabitDetailView`) is the canonical place to log
manually and to start a timer:

- "Log Today" toggle button.
- "Start N min Timer" button when `habit.timerDurationSeconds > 0`,
  presenting `TimerView`.
- Three stat tiles (streak / total / this week).
- Month-grouped history list with per-row "Remove Log" context action.

### Timers

Habits can carry an optional countdown timer
(`Habit.timerDurationSeconds`, set in `AddHabitView`'s "Timer" section
— Off / 1 / 5 / 10 / 15 / 25 / 30 / 45 / 60 min). `TimerView` is a
foreground sheet with a circular progress ring, pause/resume/reset, and
auto-logs the habit on completion (only if not already logged today).
Cancelling the sheet before completion does **not** log.

## Conventions

- **Styling:** wrap any glass surface with `.glassCard(cornerRadius:tint:)`.
  Use `AppColors.tilePalette` for habit colors and
  `AppColors.streakColor(for:)` for the warm streak-heat ramp.
- **Typography:** rounded SF (`.system(..., design: .rounded)`); tile
  titles are `.heavy`/`.black` weights; labels use uppercase small caps
  with `tracking(1.2)`.
- **Haptics:** route every tactile moment through `Haptics.*`. Don't
  instantiate `UIImpactFeedbackGenerator` inline.
- **Streak math:** call `Date.calculateStreak(from:)`; do not duplicate
  the day-grace logic. A streak survives one missed day until the
  calendar rolls over.
- **HealthKit:** new HealthKit-backed habit types should extend
  `HealthKitSource` (label, defaultTarget, unitSuffix, symbol) and add a
  matching branch in `HealthKitService.todayValue(for:)`.
- **SwiftData enums:** persist as `String` raw values
  (`frequencyRaw`, `sourceRaw`) with a computed property exposing the
  enum. This keeps migrations painless.
- **Dark mode only:** the app is locked to `.preferredColorScheme(.dark)`.
  Do not introduce light-mode color variants.

## Editing rules for AI agents

1. **One responsibility per file.** Views >150 lines should be split
   (e.g. `HabitDetailView` + `HabitHistoryGroup`).
2. **Match surrounding comment density.** Brief doc comments on types
   and non-obvious gestures; no rationale-for-this-change comments.
3. **Never edit `project.pbxproj` to add files** — synchronized groups
   handle that. Only touch it for build-setting / capability changes.
4. **Preserve the gesture contract** above when adding new tile-like
   surfaces.
5. **Don't create README/docs files** unless asked. CLAUDE.md is the
   sanctioned doc surface.
6. **Tests:** there is no test target yet. If adding logic that benefits
   from tests (streak math, HealthKit value mapping), surface the
   suggestion to the user before scaffolding a target.

## Known gaps / future work

- App icon PNG is not yet present in
  `Assets.xcassets/AppIcon.appiconset/` (the `Contents.json` slot is
  defined; a 1024×1024 image needs to be dropped in).
- HealthKit auto-sync only inserts a completion when today's value
  meets the target; partial-progress UI on the tile is not yet shown.
- No notifications / reminders. If added, use `UNUserNotificationCenter`
  and gate behind an explicit settings toggle.
