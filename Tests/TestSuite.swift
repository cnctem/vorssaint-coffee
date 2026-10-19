// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Shared assertions for the streamlined test run. Recording a failure never
/// stops the remaining assertions; the runner owns the exit code.
final class TestSuite {
    private let lock = NSLock()
    private(set) var checks = 0
    private(set) var failures: [String] = []

    func expect(_ condition: Bool, _ message: @autoclosure () -> String,
                file: StaticString = #filePath, line: UInt = #line) {
        let failure = condition ? nil : "\(file):\(line): \(message())"
        lock.withLock {
            checks += 1
            if let failure { failures.append(failure) }
        }
    }

    func expectClose(_ actual: Double, _ expected: Double, _ label: String,
                     tol: Double = 0.0001, file: StaticString = #filePath, line: UInt = #line) {
        expect(actual.isFinite && expected.isFinite && tol.isFinite && tol >= 0
                   && abs(actual - expected) <= tol,
               "\(label): got \(actual), expected \(expected) within \(tol)", file: file, line: line)
    }

    func run(_ name: String, _ body: () -> Void) {
        let before = checks
        let previousFailures = failures.count
        let started = ProcessInfo.processInfo.systemUptime
        body()
        if checks == before { expect(false, "\(name) executed no assertions") }
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let status = failures.count == previousFailures ? "OK" : "FAILED"
        print("\(name): \(status) (\(checks - before) checks, \(String(format: "%.2f", elapsed))s)")
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("TESTS OK (\(checks) checks)")
            exit(0)
        }
        print("TESTS FAILED (\(failures.count) of \(checks)):")
        failures.forEach { print("  - \($0)") }
        exit(1)
    }
}

enum TestHarnessTests {
    static func run(_ suite: TestSuite) {
        let rejected = TestSuite()
        for invalid in [Double.nan, .infinity, -.infinity] {
            rejected.expectClose(invalid, 1, "invalid result")
            rejected.expectClose(1, invalid, "invalid expectation")
            rejected.expectClose(1, 1, "invalid tolerance", tol: invalid)
        }
        rejected.expectClose(1, 1, "negative tolerance", tol: -1)
        rejected.expectClose(2, 1, "wrong finite result")
        suite.expect(rejected.failures.count == 11, "every invalid numeric comparison fails")

        let accepted = TestSuite()
        accepted.expectClose(1, 1, "exact", tol: 0)
        accepted.expectClose(1.25, 1, "inclusive tolerance", tol: 0.25)
        accepted.expectClose(-1.25, -1, "negative values", tol: 0.25)
        suite.expect(accepted.failures.isEmpty && accepted.checks == 3,
                     "finite comparisons retain exact and tolerance-boundary behavior")
    }
}
