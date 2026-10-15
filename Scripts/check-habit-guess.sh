#!/bin/sh
# Builds the habit name reader and checks it on known names.
set -e
cd "$(dirname "$0")/.."
out=$(mktemp -d)
swiftc -o "$out/check" "Habit Formed/Extensions/Double+Helpers.swift" "Habit Formed/Models/HabitGuess.swift" Scripts/HabitGuessCheck/main.swift
"$out/check"
