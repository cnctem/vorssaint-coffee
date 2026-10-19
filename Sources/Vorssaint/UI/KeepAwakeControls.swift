// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The offered durations in minutes; 0 keeps the session open until it is
/// switched off.
enum DurationPicker {
    static let choices = [15, 30, 60, 120, 240, 480, 0]

    static func title(for minutes: Int, _ s: Strings) -> String {
        switch minutes {
        case 15: return s.minutes15
        case 30: return s.minutes30
        case 60: return s.hour1
        case 120: return s.hours2
        case 240: return s.hours4
        case 480: return s.hours8
        default: return s.indefinite
        }
    }

    /// Chip-sized label ("15m", "1h" in English), localized by Foundation.
    static func shortTitle(for minutes: Int, _ s: Strings, _ language: AppLanguage) -> String {
        guard minutes > 0 else { return "∞" }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language.rawValue)
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? title(for: minutes, s)
    }
}

/// Capsule chip used for the Keep awake presets and extensions.
struct KeepAwakeChipStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(isSelected
                ? Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1)
                : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07)))
            .contentShape(Capsule())
    }
}

struct KeepAwakeMouseJiggleIntervalPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Defaults.allowedKeepAwakeMouseJiggleIntervals, id: \.self) { minutes in
                Text(Self.label(for: minutes)).tag(minutes)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .fixedSize()
    }

    static func label(for minutes: Int) -> String {
        "\(minutes) min"
    }
}
