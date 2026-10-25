import Foundation

/// What a habit's name says about it: a glyph for the activity, and the
/// numbers it gives ("Read 20 min", "10k steps", "Gym 3x a week", "Water the
/// plants every 3 days"). Read on each keystroke of the add page and from a
/// name said to Siri, so it is words and patterns only; a name that says
/// nothing comes back empty.
nonisolated struct HabitGuess: Equatable, Sendable {
    var symbol: String?
    /// An Apple Health metric the name counts in, and its goal when given
    /// (a weekly total when the name says "a week").
    var source: HealthKitSource?
    var target: Double?
    /// A timer's length, for a duration that is not a Health metric.
    var minutes: Int?
    var frequency: HabitFrequency?
    var weeklyTarget: Int?
    var intervalDays: Int?
    /// The days of the week the name gives ("Mon Wed Fri", "on weekends"), as
    /// `Calendar` weekdays (1 is Sunday): its reminder's days.
    var weekdays: Set<Int>?
    /// The name without its schedule, first letter capitalized ("Gym" from
    /// "gym 3 times a week"): what a habit made by Siri is called.
    var title = ""

    static func read(_ name: String) -> HabitGuess {
        let pieces = Piece.split(name)
        let words = pieces.map(\.word)
        func word(_ index: Int) -> String { words.indices.contains(index) ? words[index] : "" }
        func says(_ stems: [String]) -> Bool { words.contains { word in stems.contains { matches(word, $0) } } }

        var amounts = Amounts()
        var weeklyCount: Int?
        var everyDays: Int?
        var daily = words.contains("daily")
        var schedule: [Range<String.Index>] = []
        var weekdays: Set<Int> = []
        var lastDay = -2
        // "Sun" and "wed" are words too, so a short day counts only in a
        // list of days or after "on" or "every".
        let listsDays = words.filter { dayNames[$0] ?? dayNames[String($0.dropLast())] ?? shortDays[$0] != nil }.count > 1

        var index = 0
        while index < pieces.count {
            let piece = pieces[index]
            defer { index += 1 }

            // "Mon Wed Fri", "on Mondays and Thursdays", "every weekend"
            let leadsIn = ["on", "every"].contains(word(index - 1))
            if let days = named(piece.word, short: listsDays || leadsIn) {
                weekdays.formUnion(days)
                let joined = lastDay == index - 1 || (lastDay == index - 2 && ["and", "or"].contains(word(index - 1)))
                if joined, let last = schedule.indices.last {
                    schedule[last] = schedule[last].lowerBound..<piece.range.upperBound
                } else {
                    schedule.append((leadsIn ? pieces[index - 1].range.lowerBound : piece.range.lowerBound)..<piece.range.upperBound)
                }
                lastDay = index
                continue
            }

            // "every day", "every other day", "every 3 days", "every week"
            if piece.word == "every" {
                var count = 1.0
                var end = index + 1
                if word(end) == "other" {
                    count = 2
                    end += 1
                } else if word(end) == "single" {
                    end += 1
                } else if let number = pieces.indices.contains(end) ? pieces[end].number : nil {
                    count = number
                    end += 1
                }
                let isWeek = weekWords.contains(word(end))
                guard isWeek || dayWords.contains(word(end)), count >= 1 else { continue }
                schedule.append(piece.range.lowerBound..<pieces[end].range.upperBound)
                index = end
                let days = isWeek ? count * 7 : count
                if isWeek && count == 1 {
                    weeklyCount = 1
                } else if days == 1 {
                    daily = true
                } else {
                    everyDays = min(days.safeRounded, 90)
                }
                continue
            }

            // "3 times a week", "4x a week", "twice a week", "5 days per week"
            let times = timesWords[piece.word]
            if let count = times ?? piece.number, (1...7).contains(count), count == count.rounded() {
                var end = index + 1
                let counted = times != nil || countWords.contains(word(end))
                if times == nil && counted { end += 1 }
                if counted && linkWords.contains(word(end)) { end += 1 }
                if counted && (weekWords.contains(word(end)) || word(end) == "weekly") {
                    weeklyCount = Int(count)
                    schedule.append(piece.range.lowerBound..<pieces[end].range.upperBound)
                    index = end
                    continue
                }
            }

            // "an hour", "half an hour"
            if hourWords.contains(piece.word), index > 0, pieces[index - 1].number == nil {
                let before = word(index - 1)
                if before == "half" || word(index - 2) == "half" {
                    amounts.minutes = 30
                } else if before == "a" || before == "an" {
                    amounts.minutes = 60
                    amounts.hours = 1
                }
                continue
            }

            // A number and its unit: "20 min", "10k steps", "5k", "8 hours"
            guard let number = piece.number else { continue }
            let unit = word(index + 1)
            if unit == "k" {
                let after = word(index + 2)
                if stepWords.contains(after) {
                    amounts.steps = number * 1000
                } else if calorieWords.contains(after) {
                    amounts.kcal = number * 1000
                } else {
                    // "Run 5k"
                    amounts.km = number
                }
            } else if stepWords.contains(unit) {
                amounts.steps = number
            } else if calorieWords.contains(unit) {
                amounts.kcal = number
            } else if minuteWords.contains(unit) {
                amounts.minutes = number
            } else if hourWords.contains(unit) {
                amounts.minutes = number * 60
                amounts.hours = number
            } else if kmWords.contains(unit) {
                amounts.km = number
            } else if mileWords.contains(unit) {
                amounts.km = (number * 16.09).rounded() / 10
            } else if floorWords.contains(unit) {
                amounts.floors = number
            }
        }

        var guess = HabitGuess()

        // A Health metric checks itself off, so it comes first.
        if let steps = amounts.steps {
            guess.source = .steps
            guess.target = steps
        } else if says(["steps"]) {
            guess.source = .steps
        } else if let kcal = amounts.kcal, says(["burn*", "active"]) {
            guess.source = .activeCalories
            guess.target = kcal
        } else if let km = amounts.km, says(["walk*", "run", "running", "jog", "jogging", "hike", "hiking"]) {
            guess.source = .walkingDistance
            guess.target = km
        } else if let floors = amounts.floors {
            guess.source = .flightsClimbed
            guess.target = floors
        } else if let hours = amounts.hours, (4...14).contains(hours), says(["sleep*"]) {
            guess.source = .sleepHours
            guess.target = hours
        } else if let hours = amounts.hours, (2...16).contains(hours), says(["stand", "standing"]) {
            guess.source = .standHours
            guess.target = hours
        } else if let minutes = amounts.minutes, says(["exercise"]) {
            guess.source = .exerciseMinutes
            guess.target = minutes
        } else if let minutes = amounts.minutes, says(["mindful*"]) {
            guess.source = .mindfulMinutes
            guess.target = minutes
        } else if let minutes = amounts.minutes, (1...240).contains(minutes) {
            guess.minutes = minutes.safeRounded
        }

        // Days of the week are that many a week ("Gym Mon Wed Fri" is 3), and
        // all seven are every day.
        if weekdays.count == 7 {
            daily = true
        } else if !weekdays.isEmpty {
            guess.weekdays = weekdays
            weeklyCount = weeklyCount ?? weekdays.count
        }

        // A count a week makes it a weekly habit, checked off by hand: Health
        // only knows a week as one total.
        if let count = weeklyCount {
            guess.source = nil
            guess.target = nil
            guess.frequency = .weekly
            guess.weeklyTarget = count
        } else if guess.source != nil {
            if says(["week", "weekly"]) {
                guess.frequency = .weekly
            } else if daily {
                guess.frequency = .daily
            }
        } else if let days = everyDays, guess.minutes == nil {
            guess.frequency = .interval
            guess.intervalDays = days
        } else if words.contains("weekly") {
            guess.frequency = .weekly
            guess.weeklyTarget = 1
        } else if daily {
            guess.frequency = .daily
        }

        if let first = words.first, negations.contains(first) {
            guess.symbol = "nosign"
        } else {
            guess.symbol = glyphs.first { says($0.stems) }?.symbol ?? guess.source?.symbol
        }

        var title = name
        for range in schedule.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            title.removeSubrange(range)
        }
        title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
        if title.isEmpty {
            title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guess.title = title.prefix(1).uppercased() + title.dropFirst()
        return guess
    }

    /// The weekdays a word names: "monday", "mondays", "weekends", and with
    /// `short` "mon" or "thurs".
    private static func named(_ word: String, short: Bool) -> Set<Int>? {
        if let day = dayNames[word] ?? dayNames[String(word.dropLast())] { return [day] }
        if word == "weekday" || word == "weekdays" { return [2, 3, 4, 5, 6] }
        if word == "weekend" || word == "weekends" { return [1, 7] }
        if short, let day = shortDays[word] { return [day] }
        return nil
    }

    /// A whole word, or its plural; a stem ending in "*" takes any word that
    /// starts with it.
    private static func matches(_ word: String, _ stem: String) -> Bool {
        if stem.hasSuffix("*") { return word.hasPrefix(stem.dropLast()) }
        return word == stem || word == stem + "s"
    }

    // MARK: - Pieces

    /// A run of letters (lowercased) or a number, where it sits in the name.
    /// Letters run into a number split off: "10k" is 10, then "k".
    private nonisolated struct Piece {
        let word: String
        let number: Double?
        let range: Range<String.Index>

        static func split(_ text: String) -> [Piece] {
            func isDigit(_ character: Character) -> Bool { character.isASCII && character.isNumber }
            var pieces: [Piece] = []
            var start = text.startIndex
            while start < text.endIndex {
                var end = text.index(after: start)
                if isDigit(text[start]) {
                    var digits = String(text[start])
                    while end < text.endIndex {
                        let character = text[end]
                        let next = text.index(after: end)
                        let digitFollows = next < text.endIndex && isDigit(text[next])
                        if isDigit(character) {
                            digits.append(character)
                        } else if character == ",", digitFollows {
                            // "10,000"
                        } else if character == ".", digitFollows, !digits.contains(".") {
                            digits.append(character)
                        } else {
                            break
                        }
                        end = next
                    }
                    pieces.append(Piece(word: "", number: Double(digits), range: start..<end))
                } else if text[start].isLetter {
                    while end < text.endIndex, text[end].isLetter || text[end] == "'" {
                        end = text.index(after: end)
                    }
                    let word = text[start..<end].lowercased()
                    pieces.append(Piece(word: word, number: HabitGuess.numberWords[word], range: start..<end))
                }
                start = end
            }
            return pieces
        }
    }

    private nonisolated struct Amounts {
        var steps: Double?
        var kcal: Double?
        var km: Double?
        var floors: Double?
        var minutes: Double?
        var hours: Double?
    }

    // MARK: - Words

    private static let numberWords: [String: Double] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "twelve": 12, "fifteen": 15, "twenty": 20,
        "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "ninety": 90,
    ]
    private static let timesWords: [String: Double] = ["once": 1, "twice": 2, "thrice": 3]
    private static let countWords: Set<String> = ["x", "times", "time", "days", "day"]
    private static let linkWords: Set<String> = ["a", "per", "each", "every", "in", "the", "this"]
    private static let dayWords: Set<String> = ["day", "days"]
    private static let weekWords: Set<String> = ["week", "weeks", "wk", "wks"]
    private static let stepWords: Set<String> = ["step", "steps"]
    private static let calorieWords: Set<String> = ["kcal", "cal", "cals", "calorie", "calories"]
    private static let minuteWords: Set<String> = ["m", "min", "mins", "minute", "minutes"]
    private static let hourWords: Set<String> = ["h", "hr", "hrs", "hour", "hours"]
    private static let kmWords: Set<String> = ["km", "kms", "kilometer", "kilometers", "kilometre", "kilometres"]
    private static let mileWords: Set<String> = ["mi", "mile", "miles"]
    private static let floorWords: Set<String> = ["floor", "floors", "flight", "flights"]
    private static let negations: Set<String> = ["no", "quit", "stop", "avoid", "skip"]
    private static let dayNames: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7,
    ]
    private static let shortDays: [String: Int] = [
        "sun": 1, "mon": 2, "tue": 3, "tues": 3, "wed": 4, "weds": 4,
        "thu": 5, "thur": 5, "thurs": 5, "fri": 6, "sat": 7,
    ]

    // ponytail: first row with a match wins, so things (the dog, the plants)
    // come before what is done to them (walk, water), and times of day last.
    // Add a row when a common name lands nowhere.
    private static let glyphs: [(symbol: String, stems: [String])] = [
        ("pawprint.fill", ["dog", "cat", "pet", "puppy", "kitten"]),
        ("headphones", ["podcast*", "audiobook*", "listen*"]),
        ("leaf.fill", ["plant*", "garden*", "flower*"]),
        ("figure.stairs", ["stair*", "floor", "flight"]),
        ("figure.stand", ["stand", "standing"]),
        ("brain.head.profile", ["medita*", "mindful*"]),
        ("lungs.fill", ["breath*"]),
        ("figure.yoga", ["yoga", "stretch*", "pilates"]),
        ("figure.pool.swim", ["swim*"]),
        ("bicycle", ["bike", "biking", "cycle", "cycling", "ride", "spin"]),
        ("figure.hiking", ["hike", "hiking"]),
        ("figure.climbing", ["climb*", "boulder*"]),
        ("figure.dance", ["danc*"]),
        ("figure.core.training", ["pushup", "situp", "squat", "plank", "abs", "core", "crunch*", "burpee"]),
        ("dumbbell.fill", ["gym", "workout", "lift", "lifting", "weights", "strength", "train", "training"]),
        ("figure.run", ["run", "running", "jog", "jogging", "sprint", "cardio", "exercise", "marathon"]),
        ("figure.walk", ["walk*", "steps"]),
        ("scalemass.fill", ["weigh", "weight"]),
        ("cup.and.saucer.fill", ["coffee", "tea", "matcha"]),
        ("drop.fill", ["water", "hydrate", "hydration", "drink"]),
        ("carrot.fill", ["fruit", "veg", "veggie", "vegetable", "salad", "greens"]),
        ("fork.knife", ["eat", "eating", "cook*", "meal*", "breakfast", "lunch", "dinner", "diet", "food", "protein", "fasting", "snack"]),
        ("pills.fill", ["vitamin*", "supplement*", "pill", "med", "meds", "medicine", "medication", "creatine"]),
        ("shower.fill", ["shower"]),
        ("mouth.fill", ["floss*", "teeth", "brush"]),
        ("sparkles", ["skincare", "skin", "moisturi*", "sunscreen"]),
        ("pianokeys", ["piano", "keyboard"]),
        ("guitars.fill", ["guitar", "ukulele", "bass"]),
        ("music.note", ["music", "sing", "singing", "song", "violin", "drum", "instrument"]),
        ("globe", ["spanish", "french", "german", "italian", "japanese", "chinese", "korean", "language*", "duolingo"]),
        ("graduationcap.fill", ["study", "studying", "homework", "class", "course", "learn*", "revise", "revision", "exam*", "lecture"]),
        ("book.fill", ["read", "reading", "book", "chapter", "novel", "bible", "page"]),
        ("pencil", ["journal*", "write", "writing", "diary", "blog"]),
        ("laptopcomputer", ["code", "coding", "program*", "computer"]),
        ("puzzlepiece.fill", ["puzzle", "sudoku", "crossword", "wordle", "chess"]),
        ("gamecontroller.fill", ["game", "gaming"]),
        ("paintbrush.fill", ["paint*", "draw", "drawing", "sketch*", "art"]),
        ("camera.fill", ["photo*", "picture"]),
        ("phone.fill", ["call"]),
        ("message.fill", ["text", "message"]),
        ("envelope.fill", ["email", "inbox", "letter"]),
        ("person.2.fill", ["friend", "family", "mom", "dad", "parents", "grandma", "grandpa", "date"]),
        ("heart.fill", ["gratitude", "grateful", "thankful", "kind", "kindness", "love", "pray", "prayer"]),
        ("face.smiling", ["mood", "smile"]),
        ("washer.fill", ["laundry"]),
        ("trash.fill", ["trash", "garbage", "recycling"]),
        ("house.fill", ["clean", "cleaning", "tidy", "chore", "declutter", "vacuum", "dishes"]),
        ("dollarsign.circle.fill", ["budget*", "money", "save", "saving", "invest*", "spend", "spending", "financ*"]),
        ("checklist", ["plan", "planning", "todo", "review"]),
        ("scope", ["focus*", "deep"]),
        ("iphone", ["screen", "phone", "social", "scroll*"]),
        ("moon.zzz.fill", ["bedtime"]),
        ("bed.double.fill", ["sleep*", "nap", "bed"]),
        ("alarm.fill", ["wake", "waking", "early", "alarm"]),
        ("sun.max.fill", ["sun", "sunlight", "outside", "outdoors", "morning"]),
        ("moon.fill", ["night", "evening"]),
    ]
}
