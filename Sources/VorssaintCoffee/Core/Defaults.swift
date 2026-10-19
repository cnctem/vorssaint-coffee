// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Every UserDefaults key the streamlined keep-awake app uses.
enum DefaultsKey {
    static let language = "appLanguage"                   // AppLanguage.rawValue
    static let clamshellPreferred = "clamshellPreferred"  // apply closed-lid mode to every session
    static let dimScreenOnLidClose = "dimScreenOnLidClose" // dim the built-in display while the lid is closed
    static let defaultDuration = "defaultDurationMinutes" // 0 = indefinite
    static let batteryLimit = "batteryLimitPercent"       // 0 = never
    static let keepAwakeAutoStart = "keepAwakeAutoStart"  // start Keep Awake when the app launches
    static let keepAwakeRightClickToggle = "keepAwakeRightClickToggle"
    static let keepAwakeAllowDisplaySleep = "keepAwakeAllowDisplaySleep"
    static let keepAwakeExternalDisplay = "keepAwakeExternalDisplay"
    static let keepAwakeConnectedToPower = "keepAwakeConnectedToPower"
    static let keepAwakeRunningApps = "keepAwakeRunningApps"
    static let keepAwakeRunningAppBundleIDs = "keepAwakeRunningAppBundleIDs"
    // Match mode over the automation conditions: false is Any, true is All.
    static let keepAwakeAutomationRequireAll = "keepAwakeAutomationRequireAll"
    static let keepAwakePauseWhenLocked = "keepAwakePauseWhenLocked"
    static let keepAwakeSwitchUsesUntil = "keepAwakeSwitchUsesUntil"
    static let keepAwakeUntilTime = "keepAwakeUntilTime"  // last picked end time; 0 = none yet
    static let keepAwakeMouseJiggleEnabled = "keepAwakeMouseJiggleEnabled"
    static let keepAwakeMouseJiggleInterval = "keepAwakeMouseJiggleIntervalMinutes"
    static let hotkeyEnabled = "hotkeyEnabled"
    static let launchAtLoginWanted = "launchAtLoginWanted"  // the user's choice
    static let keepAwakeShortcut = "keepAwakeShortcut"    // KeepAwakeShortcut storage value
    static let keepAwakeIconTint = "keepAwakeIconTint"    // KeepAwakeIconTint.rawValue
    static let keepAwakeActiveIcon = "keepAwakeActiveIcon" // KeepAwakeActiveIcon.rawValue
    static let showCountdown = "showCountdownInMenuBar"
    static let sleepDisabledFlag = "vorssDisabledSleep"   // internal guard for pmset disablesleep
    static let dimmedDisplaySavedBrightness = "vorssDimmedDisplaySavedBrightness"
    static let startupDidNotFinish = "startupDidNotFinish"
}

/// Feature availability for the one feature this build keeps. The original
/// hub could switch features on and off; the streamlined app has Keep Awake
/// installed permanently, so every availability check answers yes.
enum AppFeature {
    enum keepAwake {
        static let isAvailable = true
    }
}

enum KeepAwakeIconTint: String, CaseIterable, Identifiable {
    case orange, green, blue, purple, pink, none

    var id: String { rawValue }

    static var current: KeepAwakeIconTint {
        Defaults.sanitizedKeepAwakeIconTint(
            UserDefaults.standard.string(forKey: DefaultsKey.keepAwakeIconTint)
        )
    }

    func title(_ strings: Strings) -> String {
        switch self {
        case .orange: return strings.keepAwakeIconTintOrange
        case .green: return strings.keepAwakeIconTintGreen
        case .blue: return strings.keepAwakeIconTintBlue
        case .purple: return strings.keepAwakeIconTintPurple
        case .pink: return strings.keepAwakeIconTintPink
        case .none: return strings.keepAwakeIconTintNone
        }
    }
}

enum KeepAwakeActiveIcon: String, CaseIterable, Identifiable {
    case vorssaint, coffee, eye, moon, light

    var id: String { rawValue }

    static var current: KeepAwakeActiveIcon {
        Defaults.sanitizedKeepAwakeActiveIcon(
            UserDefaults.standard.string(forKey: DefaultsKey.keepAwakeActiveIcon)
        )
    }

    var systemSymbolName: String? {
        switch self {
        case .vorssaint: return nil
        case .coffee: return "cup.and.saucer.fill"
        case .eye: return "eye.fill"
        case .moon: return "moon.fill"
        case .light: return "lightbulb.fill"
        }
    }

    /// Nudge down the menu bar canvas, in points. Symbols carrying their mass
    /// above the shape's middle — steam over a cup, a bulb over its base — read
    /// as sitting high when their ink is centered geometrically.
    var menuBarDrop: CGFloat {
        switch self {
        case .coffee: return 1
        case .light: return 0.5
        case .vorssaint, .eye, .moon: return 0
        }
    }

    func title(_ strings: Strings) -> String {
        switch self {
        case .vorssaint: return strings.keepAwakeActiveIconVorssaint
        case .coffee: return strings.keepAwakeActiveIconCoffee
        case .eye: return strings.keepAwakeActiveIconEye
        case .moon: return strings.keepAwakeActiveIconMoon
        case .light: return strings.keepAwakeActiveIconLight
        }
    }
}

/// The tuned choices the keep-awake controls offer and sanitize against.
enum Defaults {
    static let allowedDurations = [15, 30, 60, 120, 240, 480, 0]
    static let allowedKeepAwakeMouseJiggleIntervals = [1, 2, 5, 10, 15]
    static let allowedBatteryLimits = [0, 5, 10, 15, 20]

    static func sanitizedDefaultDuration(_ minutes: Int) -> Int {
        allowedDurations.contains(minutes) ? minutes : 0
    }

    static func sanitizedBatteryLimit(_ percent: Int) -> Int {
        allowedBatteryLimits.contains(percent) ? percent : 10
    }

    static func sanitizedKeepAwakeMouseJiggleInterval(_ minutes: Int) -> Int {
        allowedKeepAwakeMouseJiggleIntervals.contains(minutes) ? minutes : 5
    }

    static func sanitizedKeepAwakeIconTint(_ rawValue: String?) -> KeepAwakeIconTint {
        guard let rawValue, let tint = KeepAwakeIconTint(rawValue: rawValue) else {
            return .orange
        }
        return tint
    }

    static func sanitizedKeepAwakeActiveIcon(_ rawValue: String?) -> KeepAwakeActiveIcon {
        guard let rawValue, let icon = KeepAwakeActiveIcon(rawValue: rawValue) else {
            return .vorssaint
        }
        return icon
    }

    /// A de-duplicated list of bundle identifiers with surrounding whitespace
    /// removed. Empty entries are dropped.
    static func sanitizedBundleIdentifierList(_ bundleIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in bundleIDs {
            let bundleID = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleID.isEmpty, !seen.contains(bundleID) else { continue }
            seen.insert(bundleID)
            result.append(bundleID)
        }
        return result
    }

    /// Registers the defaults a fresh install starts from. Called once before
    /// anything reads a preference.
    static func register() {
        UserDefaults.standard.register(defaults: [
            DefaultsKey.language: AppLanguage.systemDefault.rawValue,
            DefaultsKey.clamshellPreferred: false,
            DefaultsKey.dimScreenOnLidClose: false,
            DefaultsKey.defaultDuration: 0,
            DefaultsKey.batteryLimit: 10,
            DefaultsKey.keepAwakeAutoStart: false,
            DefaultsKey.keepAwakeRightClickToggle: false,
            DefaultsKey.keepAwakeAllowDisplaySleep: false,
            DefaultsKey.keepAwakeExternalDisplay: false,
            DefaultsKey.keepAwakeConnectedToPower: false,
            DefaultsKey.keepAwakeRunningApps: false,
            DefaultsKey.keepAwakeRunningAppBundleIDs: [String](),
            DefaultsKey.keepAwakeAutomationRequireAll: false,
            DefaultsKey.keepAwakePauseWhenLocked: false,
            DefaultsKey.keepAwakeSwitchUsesUntil: false,
            DefaultsKey.keepAwakeUntilTime: 0.0,
            DefaultsKey.keepAwakeMouseJiggleEnabled: false,
            DefaultsKey.keepAwakeMouseJiggleInterval: 5,
            DefaultsKey.hotkeyEnabled: true,
            DefaultsKey.launchAtLoginWanted: false,
            DefaultsKey.keepAwakeShortcut: KeepAwakeShortcut.keepAwakeDefault.storageValue,
            DefaultsKey.keepAwakeIconTint: KeepAwakeIconTint.orange.rawValue,
            DefaultsKey.keepAwakeActiveIcon: KeepAwakeActiveIcon.vorssaint.rawValue,
            DefaultsKey.showCountdown: true,
        ])
    }
}
