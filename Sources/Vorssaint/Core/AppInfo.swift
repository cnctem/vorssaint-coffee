// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Static identity of the app, shared by the UI, notifications and tooling.
enum AppInfo {
    static let name = "Vorssaint"
    static let copyright = "© 2026 Vorssaint"
    static let websiteURL = URL(string: "https://vorssaint.com")!
    static let repositoryURL = URL(string: "https://github.com/vorssaint/vorssaint-utils")!

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// True for the local "Vorssaint (Developer)" build (bundle id ends in `.dev`).
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }
}
