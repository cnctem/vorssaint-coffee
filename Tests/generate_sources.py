#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Compile the Keep Awake production methods against test doubles, without an app.

Bodies are read verbatim on every build, never copied into a maintained fixture.
The narrow declaration/indentation contract fails closed if a method moves or
changes shape; the Swift compiler then checks the generated source normally.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/generated-tests"


def declaration(path, prefix, scope=None):
    lines = (ROOT / path).read_text().splitlines(keepends=True)
    lower, upper = 0, len(lines)
    if scope is not None:
        scopes = [i for i, line in enumerate(lines) if line.startswith(scope)]
        if len(scopes) != 1:
            raise ValueError(f"Expected one scope {scope!r} in {path}")
        lower = scopes[0] + 1
        upper = next(i for i in range(lower, len(lines)) if lines[i].rstrip() == "}")
    starts = [i for i in range(lower, upper) if lines[i].startswith(prefix)]
    if len(starts) != 1:
        raise ValueError(f"Expected one declaration {prefix!r} in {path}")
    start = starts[0]
    indent = prefix[:len(prefix) - len(prefix.lstrip())]
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == indent + "}")
    body = "".join(lines[start:end + 1])
    return f'#sourceLocation(file: {json.dumps(path)}, line: {start + 1})\n{body}\n#sourceLocation()\n'


def write(name, text):
    path = OUTPUT / name
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)

    keep_awake = "Sources/Vorssaint/Services/KeepAwakeManager.swift"
    keep_awake_methods = [
        "    func refreshPasswordlessStatus(",
        "    func activate(minutes:",
        "    func activate(until date:",
        "    func startLastPick(",
        "    func resumeAfterSystemTeardown(",
        "    private func activate(end:",
        "    func deactivate(reason:",
        "    private func applyClamshellPreference(",
        "    private func prepareClamshellPreference(",
        "    private func finishClamshellSetup(",
        "    private func markClamshellSetupFailed(",
        "    private func enableClamshell(",
        "    private func disableClamshell(",
        "    private func sleepIfLidAlreadyClosed(",
        "    func recoverIfNeeded(",
        "    private func finishRecovery(",
        "    private var clamshellNeedsRestore:",
        "    private func finishClamshellRestore(",
        "    private func recoverDimmedDisplayIfNeeded(",
        "    private func syncLidDimmingObserver(",
        "    private func lidStateMayHaveChangedForDimming(",
        "    private func applyDimmingAction(",
        "    private func attemptDisplayRestore(",
    ]
    write("KeepAwakeLidSleep.swift", "import Foundation\nimport os\n\nextension KeepAwakeLidSleepContract {\n"
          # The extracted dimming bodies unwrap `Unmanaged<KeepAwakeManager>`
          # for the IOKit callback's context; this makes that name resolve to
          # the fixture's own class instead of leaving it undefined.
          + "typealias KeepAwakeManager = Service\n"
          + "final class Service {\n"
          + "static let log = Logger(subsystem: \"vorssaint.tests\", category: \"keep-awake\")\n"
          + "var isActive = false\nvar sessionPausedForScreenLock = false\n"
          + "var isTerminating = false\nvar clamshellEnablePending = false\nvar clamshellRestorePending = false\n"
          + "var clamshellOperationGeneration = 0\nvar clamshellSetupID: UUID?\n"
          + "var lidSleepGeneration = 0\nvar lidSleepAttemptsRemaining = 0\n"
          + "var clamshellSetupInProgress = false\nvar clamshellSetupFailed = false\n"
          + "var clamshellSetupRetried = false\nvar passwordlessClamshell = true\n"
          + "var recoveryCompleted = false\nvar screenLocked = false\nvar assertionsHeld = false\n"
          + "var automationSuppressedUntilConditionsClear = false\n"
          + "var endTimer: Timer?\nvar endDate: Date?\nvar sessionTrigger: SessionTrigger?\nvar sessionMinutes: Int?\n"
          + "var activeAutomationConditions = Set<KeepAwakeAutomationCondition>()\n"
          + "var onSessionEnded: ((EndReason) -> Void)?\n"
          + "var lidDimmingNotificationPort: IONotificationPortRef?\nvar lidDimmingNotification: io_object_t = 0\n"
          + "var lidClosedForDimming: Bool?\nvar savedDisplayBrightness: Double?\n"
          + declaration(keep_awake, "    @Published private(set) var clamshellActive = false {")
                .replace("@Published private(set) ", "", 1)
          + declaration(keep_awake, "    @Published var clamshellPreferred:").replace("@Published ", "", 1)
          + declaration(keep_awake, "    @Published var dimScreenOnLidClose: Bool {").replace("@Published ", "", 1)
          + "init() { clamshellPreferred = true; dimScreenOnLidClose = false }\n"
          + "func syncScreenLockMonitoring() {}\nfunc applyAssertions() { assertionsHeld = true }\n"
          + "func releaseAssertions() { assertionsHeld = false }\nfunc scheduleEnd(at date: Date) {}\n"
          + "func startBatteryWatch() {}\nfunc stopBatteryWatch() {}\nfunc syncMouseJiggleTimer() {}\n"
          + "func stopMouseJiggleTimer() {}\nfunc stopAutomationMonitoring() {}\nfunc syncWithPreferences() {}\n"
          + "static func lidSleepIsAllowed() -> Bool { KeepAwakeAutomationSupport.lidSleepIsAllowed("
          + "systemAllowsSleep: policy, assertions: assertions) }\n"
          + "".join(declaration(keep_awake, prefix).replace("private ", "", 1) for prefix in keep_awake_methods)
          + "}\n}\n"
          + "extension KeepAwakeLidSleepContract.Sudoers {\n"
          + declaration("Sources/Vorssaint/Services/ShellSupport.swift", "    static func isConfigured()")
          + declaration("Sources/Vorssaint/Services/ShellSupport.swift", "    static func restoreSleepWithAuthorization(")
          + "}\n")
    write("KeepAwakeTimerHandoff.swift", "import Foundation\n\nextension KeepAwakeTimerHandoffContract {\n"
          + "final class Service {\nvar sessionTrigger = SessionTrigger.manual\n"
          + "var automationSuppressedUntilConditionsClear = false\n"
          + "var activeAutomationConditions: Set<KeepAwakeAutomationCondition> = []\n"
          + "var enabled: Set<KeepAwakeAutomationCondition> = []\n"
          + "var matching: Set<KeepAwakeAutomationCondition> = []\n"
          + "var requireAll = false\nvar batteryAllows = true\n"
          + "var activations: [(end: Date?, trigger: SessionTrigger)] = []\n"
          + "func automaticSessionAllowedByBatteryProtection() -> Bool { batteryAllows }\n"
          + "func currentMatchingAutomationConditions() -> Set<KeepAwakeAutomationCondition> { matching }\n"
          + "func currentEnabledAutomationConditions() -> Set<KeepAwakeAutomationCondition> { enabled }\n"
          + "func automationRequiresAllConditions() -> Bool { requireAll }\n"
          + "func activate(end: Date?, trigger: SessionTrigger) { activations.append((end, trigger)) }\n"
          + declaration(keep_awake, "    private func continueAutomaticallyAfterTimerIfNeeded()")
            .replace("private func", "func", 1)
          + "}\n}\n")


if __name__ == "__main__":
    main()
