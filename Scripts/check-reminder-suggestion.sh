#!/bin/sh
# Builds the reminder suggester and checks it on known names.
set -e
cd "$(dirname "$0")/.."
out=$(mktemp -d)
swiftc -o "$out/check" "Habit Formed/Models/ReminderTiming.swift" "Habit Formed/Models/ReminderSuggestion.swift" Scripts/ReminderSuggestionCheck/main.swift
"$out/check"
