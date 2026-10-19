// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import ApplicationServices
import AppKit

/// The Accessibility gate the pointer-jiggle option needs. Posting synthetic
/// pointer events is the only thing in this app that requires a grant.
enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
