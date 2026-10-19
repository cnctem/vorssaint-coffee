// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation
import IOKit.ps

struct BatteryInfo: Equatable {
    let percent: Int
    let isCharging: Bool
    let isOnBattery: Bool
    let isOnExternalPower: Bool
}

/// Point-in-time system facts the keep-awake feature needs.
enum SystemInfo {
    /// Internal-battery presence is immutable for the lifetime of a Mac boot.
    /// Apple silicon desktops publish the battery service too, with
    /// BatteryInstalled false.
    static let hasInternalBattery: Bool = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let installed = IORegistryEntryCreateCFProperty(service, "BatteryInstalled" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (installed as? Bool) != false
    }()

    static func batterySnapshot() -> BatteryInfo? {
        guard hasInternalBattery else { return nil }
        guard let blobRef = IOPSCopyPowerSourcesInfo() else { return nil }
        let blob = blobRef.takeRetainedValue()
        guard let listRef = IOPSCopyPowerSourcesList(blob) else { return nil }
        let list = listRef.takeRetainedValue() as [AnyObject]
        guard let first = list.first,
              let descRef = IOPSGetPowerSourceDescription(blob, first),
              let desc = descRef.takeUnretainedValue() as? [String: Any]
        else { return nil }

        let current = desc["Current Capacity"] as? Int ?? 0
        let max = desc["Max Capacity"] as? Int ?? 100
        let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
        let charging = desc["Is Charging"] as? Bool ?? false
        let state = desc["Power Source State"] as? String ?? ""
        return BatteryInfo(percent: percent,
                           isCharging: charging,
                           isOnBattery: state == "Battery Power",
                           isOnExternalPower: state == "AC Power")
    }
}
