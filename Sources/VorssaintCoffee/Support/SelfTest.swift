// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A dependency-free check of the pure decisions the app is built on, run by
/// `build/VorssaintCoffee --selftest` in CI and by hand.
enum SelfTest {
    static func runAndExit() -> Never {
        var failures: [String] = []
        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }

        // Duration and battery sanitation.
        expect(Defaults.sanitizedDefaultDuration(30) == 30, "a preset duration survives")
        expect(Defaults.sanitizedDefaultDuration(7) == 0, "an unknown duration falls back to indefinite")
        expect(Defaults.sanitizedBatteryLimit(20) == 20, "a preset battery limit survives")
        expect(Defaults.sanitizedBatteryLimit(99) == 10, "an unknown battery limit falls back to 10")
        expect(Defaults.sanitizedKeepAwakeMouseJiggleInterval(15) == 15, "a preset jiggle interval survives")

        // Shortcut encode/decode.
        let shortcut = KeepAwakeShortcut(keyCode: 40, modifiers: [.control, .option, .command])
        expect(KeepAwakeShortcut(storageValue: shortcut.storageValue) == shortcut,
               "a shortcut round-trips through its stored form")
        expect(KeepAwakeShortcut(storageValue: "control+:garbage") == nil, "garbage storage is rejected")

        // Automation decisions.
        let enabled: Set<KeepAwakeAutomationCondition> = [.externalDisplay, .power]
        expect(KeepAwakeAutomationSupport.conditionsSatisfied(
            matching: [.externalDisplay], enabled: enabled, requireAll: false),
               "Any is satisfied by one matching condition")
        expect(!KeepAwakeAutomationSupport.conditionsSatisfied(
            matching: [.externalDisplay], enabled: enabled, requireAll: true),
               "All is not satisfied until every enabled condition holds")
        expect(KeepAwakeAutomationSupport.lidSleepIsAllowed(systemAllowsSleep: true, assertions: []),
               "an idle machine allows lid sleep")
        expect(!KeepAwakeAutomationSupport.lidSleepIsAllowed(systemAllowsSleep: false, assertions: []),
               "a disabled lid policy never forces sleep")

        // Dimming decisions.
        expect(LidDimmingSupport.lidClosed(currentBrightness: 0.6) == .dim(save: 0.6),
               "a readable panel is saved before dimming")
        expect(LidDimmingSupport.lidClosed(currentBrightness: 0) == .none,
               "a panel that already reads asleep is left alone")

        // The presets the panel offers.
        expect(DurationPicker.choices.last == 0, "the indefinite preset stays reachable")
        expect(Defaults.allowedDurations == DurationPicker.choices,
               "the offered presets and the sanitized set agree")

        guard failures.isEmpty else {
            fputs("SELFTEST FAILED (\(failures.count)):\n", stderr)
            failures.forEach { fputs("  - \($0)\n", stderr) }
            exit(1)
        }
        print("SELFTEST OK")
        exit(0)
    }
}
