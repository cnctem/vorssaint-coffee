// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

enum Shell {
    /// A command that stops answering must not keep a thread forever.
    static let defaultTimeout: TimeInterval = 5

    @discardableResult
    static func run(_ path: String,
                    _ args: [String],
                    timeout: TimeInterval = defaultTimeout,
                    maxOutputBytes: Int = 4 * 1024 * 1024)
        -> (status: Int32, output: String) {
        let result = BoundedProcessRunner.run(path, args,
                                              timeout: timeout,
                                              maxOutputBytes: maxOutputBytes)
        return (result.status, String(decoding: result.output, as: UTF8.self))
    }
}

/// Runs a command with administrator privileges (system password prompt).
enum AdminShell {
    // Vorssaint is a menu-bar agent (LSUIElement), so it is rarely the active
    // app. SecurityAgent attaches its password dialog to the requesting process;
    // when that process is an inactive agent the dialog can open behind the
    // frontmost app and read as "no prompt appeared". Bringing the app forward
    // first makes the dialog surface in focus.
    private static let promptLock = NSLock()
    private static var prompting = false

    static func runSync(_ command: String, prompt: String) -> Bool {
        promptLock.lock()
        if prompting {
            promptLock.unlock()
            return false
        }
        prompting = true
        promptLock.unlock()
        defer {
            promptLock.lock()
            prompting = false
            promptLock.unlock()
        }

        bringAppToFront()
        let source = appleScriptSource(command: command, prompt: prompt)
        // A person typing a password is not a stuck command.
        return Shell.run("/usr/bin/osascript", ["-e", source], timeout: 600).status == 0
    }

    static func run(_ command: String, prompt: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            completion(runSync(command, prompt: prompt))
        }
    }

    /// Brings the app forward so the administrator dialog opens in focus.
    private static func bringAppToFront() {
        if Thread.isMainThread {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.sync {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Thread.sleep(forTimeInterval: 0.12)
    }

    static func appleScriptSource(command: String, prompt: String) -> String {
        "do shell script \(appleScriptString(command)) with administrator privileges with prompt \(appleScriptString(prompt))"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

/// NOPASSWD rule restricted to `pmset disablesleep 0/1`, so closed-lid mode can
/// toggle without asking for the administrator password every time.
enum Sudoers {
    static let rulePath = "/etc/sudoers.d/vorssaint-clamshell"
    private static let legacyRulePaths = [
        "/etc/sudoers.d/vorssaint-utils-clamshell",
        "/etc/sudoers.d/vorss-clamshell",
    ]

    /// Serializes native writes and read/reapply probes. Authorization runs
    /// separately with probes suspended.
    private static let sleepStateQueue = DispatchQueue(label: "com.vorssaint.utils.pmset-state")
    private static var sleepStateProbeSuspensions = 0

    /// Proves the passwordless path by running it: re-applying the current
    /// SleepDisabled state through `sudo -n` changes nothing on the system and
    /// exercises the exact call the feature makes.
    static func isConfigured() -> Bool {
        sleepStateQueue.sync {
            guard sleepStateProbeSuspensions == 0 else { return false }
            let report = Shell.run("/usr/bin/pmset", ["-g"])
            guard report.status == 0 else { return false }
            return pmsetDisableSleepOnQueue(SudoersSupport.sleepDisabled(inPmsetOutput: report.output))
        }
    }

    static func install(completion: @escaping (Bool) -> Void) {
        let rule = SudoersSupport.clamshellRule(uid: getuid())
        let legacy = legacyRulePaths.joined(separator: " ")
        let command = "mkdir -p /etc/sudoers.d && chmod 0755 /etc/sudoers.d && rm -f \(legacy) && echo '\(rule)' > \(rulePath) && chmod 0440 \(rulePath) && /usr/sbin/visudo -c -f \(rulePath) || { rm -f \(rulePath); exit 1; }"
        AdminShell.run(command, prompt: L10n.shared.s.adminPromptSudoersInstall) { ok in
            completion(ok && isConfigured())
        }
    }

    /// Toggles sleep through the password-free path. Fails silently
    /// (returns false) when the rule is not installed.
    @discardableResult
    static func pmsetDisableSleep(_ on: Bool) -> Bool {
        sleepStateQueue.sync { pmsetDisableSleepOnQueue(on) }
    }

    /// Queues asynchronous writes directly in request order.
    static func pmsetDisableSleep(_ on: Bool, completion: @escaping (Bool) -> Void) {
        sleepStateQueue.async {
            completion(pmsetDisableSleepOnQueue(on))
        }
    }

    /// Completes earlier probes before authorization can restore sleep and
    /// suspends later probes until it finishes. The queue remains free for a
    /// silent restore during quit.
    static func restoreSleepWithAuthorization(prompt: String,
                                              shouldProceed: @escaping () -> Bool,
                                              completion: @escaping (Bool) -> Void) {
        sleepStateQueue.async {
            sleepStateProbeSuspensions += 1
            let finish: (Bool) -> Void = { ok in
                sleepStateQueue.async {
                    sleepStateProbeSuspensions -= 1
                    completion(ok)
                }
            }
            let report = Shell.run("/usr/bin/pmset", ["-g"])
            if report.status == 0, !SudoersSupport.sleepDisabled(inPmsetOutput: report.output) {
                finish(true)
                return
            }
            DispatchQueue.main.async {
                guard shouldProceed() else {
                    finish(false)
                    return
                }
                AdminShell.run("pmset disablesleep 0", prompt: prompt, completion: finish)
            }
        }
    }

    private static func pmsetDisableSleepOnQueue(_ on: Bool) -> Bool {
        Shell.run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "disablesleep", on ? "1" : "0"]).status == 0
    }
}
