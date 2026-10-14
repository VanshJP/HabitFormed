#!/bin/sh
# Builds the app's day math with a brute-force reference and checks they agree.
set -e
cd "$(dirname "$0")/.."
out=$(mktemp -d)
swiftc -O -o "$out/check" "Habit Formed/Extensions/Date+Helpers.swift" "Habit Formed/Models/DayLedger.swift" Scripts/DayMathCheck/main.swift
"$out/check"
