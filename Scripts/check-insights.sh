#!/bin/sh
# Builds the History insights and checks them on made-up histories.
set -e
cd "$(dirname "$0")/.."
out=$(mktemp -d)
swiftc -O -o "$out/check" "Habit Formed/Extensions/Date+Helpers.swift" "Habit Formed/Models/DayLedger.swift" "Habit Formed/Models/ReminderTiming.swift" "Habit Formed/Services/HabitInsights.swift" Scripts/InsightsCheck/main.swift
"$out/check"
