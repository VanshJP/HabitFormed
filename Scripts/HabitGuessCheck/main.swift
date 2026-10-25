// Checks the habit name reader on the add sheet's ideas and names people
// type or say to Siri. Run Scripts/check-habit-guess.sh.
import Foundation

nonisolated enum HabitFrequency: String, Sendable { case daily, weekly, interval }

nonisolated enum HealthKitSource: String, Sendable {
    case none, steps, sleepHours, mindfulMinutes, activeCalories, exerciseMinutes, walkingDistance, standHours, flightsClimbed

    var symbol: String {
        switch self {
        case .none: "hand.tap"
        case .steps: "figure.walk"
        case .sleepHours: "bed.double.fill"
        case .mindfulMinutes: "brain.head.profile"
        case .activeCalories: "flame.fill"
        case .exerciseMinutes: "figure.run"
        case .walkingDistance: "figure.hiking"
        case .standHours: "figure.stand"
        case .flightsClimbed: "figure.stairs"
        }
    }
}

func check(_ c: Bool, _ m: String) { if !c { print("MISMATCH", m); exit(1) } }
func expect(_ name: String, _ test: (HabitGuess) -> Bool) {
    let guess = HabitGuess.read(name)
    check(test(guess), "\(name): \(guess)")
}

// Each idea's typed name lands on the idea's own glyph (HabitTemplate.all).
let ideas: [(String, String)] = [
    ("Read", "book.fill"), ("Workout", "dumbbell.fill"), ("Meditate", "brain.head.profile"),
    ("Practice piano", "pianokeys"), ("10k steps", "figure.walk"), ("Sleep 7 hours", "bed.double.fill"),
    ("Burn 500 kcal", "flame.fill"), ("Drink water", "drop.fill"), ("Journal", "pencil"),
    ("Stretch", "figure.yoga"), ("Water the plants", "leaf.fill"), ("Call family", "phone.fill"),
    ("Eat clean", "fork.knife"), ("Study", "graduationcap.fill"),
]
for (name, symbol) in ideas { expect(name) { $0.symbol == symbol } }

// A plain name says only its glyph.
expect("Read") { $0.minutes == nil && $0.source == nil && $0.frequency == nil && $0.title == "Read" }
expect("Get ready") { $0.symbol == nil }
expect("Walk the dog") { $0.symbol == "pawprint.fill" }
expect("Morning run") { $0.symbol == "figure.run" }
expect("Read before bed") { $0.symbol == "book.fill" }
expect("Journal at night") { $0.symbol == "pencil" }
expect("Make the bed") { $0.symbol == "bed.double.fill" && $0.minutes == nil }
expect("No sugar") { $0.symbol == "nosign" }
expect("Learn Spanish") { $0.symbol == "globe" }
expect("Pushups") { $0.symbol == "figure.core.training" }
expect("Wake up at 6:30") { $0.symbol == "alarm.fill" && $0.minutes == nil }

// Lengths make a timer.
expect("Read 20 min") { $0.minutes == 20 && $0.source == nil }
expect("Meditate 10 minutes") { $0.minutes == 10 }
expect("Study half an hour") { $0.minutes == 30 }
expect("Read for an hour") { $0.minutes == 60 }
expect("Read 1 hour before sleep") { $0.minutes == 60 && $0.source == nil }
expect("Intermittent fasting 16 hours") { $0.minutes == nil && $0.source == nil }

// Health metrics check themselves off.
expect("10,000 steps") { $0.source == .steps && $0.target == 10_000 }
expect("Steps") { $0.source == .steps && $0.target == nil }
expect("70k steps a week") { $0.source == .steps && $0.target == 70_000 && $0.frequency == .weekly }
expect("Sleep 7.5h") { $0.source == .sleepHours && $0.target == 7.5 }
expect("Get 8 hours of sleep") { $0.source == .sleepHours && $0.target == 8 }
expect("Eat under 2000 calories") { $0.source == nil && $0.symbol == "fork.knife" }
expect("Run 5k") { $0.source == .walkingDistance && $0.target == 5 && $0.symbol == "figure.run" }
expect("Walk 3 miles") { $0.source == .walkingDistance && $0.target == 4.8 }
expect("Climb 10 floors") { $0.source == .flightsClimbed && $0.target == 10 && $0.symbol == "figure.stairs" }
expect("Exercise 30 min") { $0.source == .exerciseMinutes && $0.target == 30 && $0.minutes == nil }
expect("Stand 10 hours") { $0.source == .standHours && $0.target == 10 }
expect("Mindful 10 minutes") { $0.source == .mindfulMinutes && $0.target == 10 }

// Schedules, and the name a habit made by Siri gets.
expect("read 20 min every day") { $0.minutes == 20 && $0.frequency == .daily && $0.title == "Read 20 min" }
expect("Gym 3x a week") { $0.frequency == .weekly && $0.weeklyTarget == 3 && $0.title == "Gym" }
expect("Gym 4x/week") { $0.weeklyTarget == 4 && $0.title == "Gym" }
expect("go to the gym three times a week") { $0.weeklyTarget == 3 && $0.title == "Go to the gym" }
expect("Call mom twice a week") { $0.weeklyTarget == 2 && $0.title == "Call mom" }
expect("Water the plants every 3 days") { $0.frequency == .interval && $0.intervalDays == 3 && $0.title == "Water the plants" }
expect("Stretch every other day") { $0.intervalDays == 2 && $0.title == "Stretch" }
expect("Change sheets every 2 weeks") { $0.intervalDays == 14 && $0.title == "Change sheets" }
expect("Run every week") { $0.frequency == .weekly && $0.weeklyTarget == 1 && $0.title == "Run" }
expect("Clean the house weekly") { $0.weeklyTarget == 1 && $0.title == "Clean the house weekly" }
expect("Daily walk") { $0.frequency == .daily && $0.title == "Daily walk" }
expect("Every single day read") { $0.frequency == .daily && $0.title == "Read" }
expect("3 times a week") { $0.weeklyTarget == 3 && $0.title == "3 times a week" }
expect("Practice piano 30 min 3 times a week") { $0.minutes == 30 && $0.weeklyTarget == 3 && $0.title == "Practice piano 30 min" }
// A count a week is checked off by hand; a timer has no every-few-days.
expect("Run 5k 3 times a week") { $0.source == nil && $0.weeklyTarget == 3 && $0.title == "Run 5k" }
expect("Meditate 10 min every 2 days") { $0.minutes == 10 && $0.frequency == nil }
expect("Brush teeth twice") { $0.symbol == "mouth.fill" && $0.frequency == nil }

// Days of the week are that many a week, and the reminder's days.
expect("Gym Mon Wed Fri") { $0.frequency == .weekly && $0.weeklyTarget == 3 && $0.weekdays == [2, 4, 6] && $0.title == "Gym" }
expect("Read Mon, Wed, Fri") { $0.weekdays == [2, 4, 6] && $0.title == "Read" }
expect("Gym on Mondays and Thursdays") { $0.weeklyTarget == 2 && $0.weekdays == [2, 5] && $0.title == "Gym" }
expect("Yoga every Sunday") { $0.weeklyTarget == 1 && $0.weekdays == [1] && $0.title == "Yoga" }
expect("Run on weekends") { $0.weeklyTarget == 2 && $0.weekdays == [1, 7] && $0.title == "Run" }
expect("Stretch weekdays") { $0.weeklyTarget == 5 && $0.weekdays == [2, 3, 4, 5, 6] && $0.title == "Stretch" }
expect("Gym 4x a week Mon Tue Thu Fri") { $0.weeklyTarget == 4 && $0.weekdays == [2, 3, 5, 6] && $0.title == "Gym" }
expect("Gym 3x a week on weekdays") { $0.weeklyTarget == 3 && $0.weekdays?.count == 5 && $0.title == "Gym" }
expect("Run 5k on Saturdays") { $0.source == nil && $0.weeklyTarget == 1 && $0.weekdays == [7] && $0.title == "Run 5k" }
expect("Meditate on sun") { $0.weekdays == [1] && $0.title == "Meditate" }
// A short day alone is a word, and all seven days are every day.
expect("Get some sun") { $0.weekdays == nil && $0.frequency == nil && $0.symbol == "sun.max.fill" }
expect("Sat down to read") { $0.weekdays == nil && $0.symbol == "book.fill" }
expect("Walk Sun Mon Tue Wed Thu Fri Sat") { $0.frequency == .daily && $0.weekdays == nil && $0.title == "Walk" }

print("habit guesses match")
