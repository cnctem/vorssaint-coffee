// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

// The runner lists every independently selectable suite. A filtered run says
// exactly which suites ran; an unknown or empty selection is an error.
@main
struct KeepAwakeTests {
    static func main() {
        let suite = TestSuite()
        let groups: [(String, () -> Void)] = [
            ("harness", {
                TestHarnessTests.run(suite)
            }),
            ("keep-awake", {
                KeepAwakeLidSleepTests.run { suite.expect($0, $1) }
                KeepAwakeTimerHandoffTests.run { suite.expect($0, $1) }
                KeepAwakeClamshellTests.run { suite.expect($0, $1) }
                KeepAwakeDimmingTests.run { suite.expect($0, $1) }
            }),
        ]
        var selected = Set<String>()
        var listOnly = false
        for argument in CommandLine.arguments.dropFirst() {
            if argument == "--list" {
                listOnly = true
                continue
            }
            guard argument.hasPrefix("--suite="),
                  groups.contains(where: { $0.0 == String(argument.dropFirst(8)) }) else {
                fputs("Unknown test selection: \(argument)\n", stderr)
                exit(2)
            }
            selected.insert(String(argument.dropFirst(8)))
        }
        if listOnly {
            groups.forEach { print($0.0) }
            exit(0)
        }
        let chosen = selected.isEmpty ? nil : selected
        for (name, body) in groups where chosen?.contains(name) ?? true {
            suite.run(name, body)
        }
        suite.finish()
    }
}
