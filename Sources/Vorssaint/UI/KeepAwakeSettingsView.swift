// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The whole Settings window of the streamlined app: one page of Keep Awake
/// options, the menu bar appearance, general behavior and About.
struct KeepAwakeSettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared

    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration = 0
    @AppStorage(DefaultsKey.batteryLimit) private var batteryLimit = 10
    @AppStorage(DefaultsKey.keepAwakeAutoStart) private var keepAwakeAutoStart = false
    @AppStorage(DefaultsKey.keepAwakeRightClickToggle) private var keepAwakeRightClickToggle = false
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var keepAwakeAllowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var keepAwakePauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeIconTint) private var keepAwakeIconTint = KeepAwakeIconTint.orange.rawValue
    @AppStorage(DefaultsKey.keepAwakeActiveIcon) private var keepAwakeActiveIcon = KeepAwakeActiveIcon.vorssaint.rawValue
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var keepAwakeMouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var keepAwakeMouseJiggleInterval = 5
    @AppStorage(DefaultsKey.showCountdown) private var showCountdown = true
    @AppStorage(DefaultsKey.hotkeyEnabled) private var hotkeyEnabled = true

    @State private var loginRegistration: LaunchAtLoginSupport.Registration = .off
    @State private var loginError: String?
    @State private var shortcut = KeepAwakeShortcut.saved(for: DefaultsKey.keepAwakeShortcut,
                                                         fallback: .keepAwakeDefault)
    @State private var recordingShortcut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.s.settingsTitle).font(.title2.bold())
                    Text(l10n.s.keepAwakeTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                sessionCard
                automationCard
                pointerCard
                if SystemInfo.hasInternalBattery { batteryCard }
                clamshellCard
                menuBarCard
                generalCard
                aboutCard
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear {
            defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration)
            batteryLimit = Defaults.sanitizedBatteryLimit(batteryLimit)
            keepAwakeIconTint = Defaults.sanitizedKeepAwakeIconTint(keepAwakeIconTint).rawValue
            keepAwakeActiveIcon = Defaults.sanitizedKeepAwakeActiveIcon(keepAwakeActiveIcon).rawValue
            keepAwakeMouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(keepAwakeMouseJiggleInterval)
            awake.refreshPasswordlessStatus()
            refreshLaunchAtLogin()
        }
    }

    // MARK: - Session

    private var sessionCard: some View {
        SettingsCard(title: l10n.s.sessionSection) {
            SettingsRow(symbol: "moon.zzz.fill", title: l10n.s.keepAwakeTitle, caption: sessionStatus) {
                Toggle(l10n.s.keepAwakeTitle, isOn: activeBinding).labelsHidden()
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.s.defaultDurationLabel)
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                    ForEach(DurationPicker.choices, id: \.self) { minutes in
                        durationChip(minutes)
                    }
                }
            }
            Divider()
            SettingsRow(symbol: "play.circle", title: l10n.s.keepAwakeAutoStart,
                        caption: l10n.s.keepAwakeAutoStartCaption) {
                Toggle(l10n.s.keepAwakeAutoStart, isOn: $keepAwakeAutoStart).labelsHidden()
            }
            SettingsRow(symbol: "timer", title: l10n.s.showCountdown) {
                Toggle(l10n.s.showCountdown, isOn: $showCountdown).labelsHidden()
            }
            SettingsRow(symbol: "cursorarrow.click.2", title: l10n.s.keepAwakeRightClickToggle,
                        caption: l10n.s.keepAwakeRightClickToggleCaption) {
                Toggle(l10n.s.keepAwakeRightClickToggle, isOn: $keepAwakeRightClickToggle).labelsHidden()
            }
            SettingsRow(symbol: "display", title: displaySleepStrings.allowDisplaySleep,
                        caption: displaySleepStrings.allowDisplaySleepCaption) {
                Toggle(displaySleepStrings.allowDisplaySleep, isOn: $keepAwakeAllowDisplaySleep).labelsHidden()
            }
        }
    }

    private var sessionStatus: String {
        guard awake.isActive else { return l10n.s.keepAwakeNormalRules }
        if awake.sessionTrigger == .automation {
            return automationStrings.activeStatus(for: awake.activeAutomationConditions)
        }
        return l10n.s.keepAwakeUntilDisabled
    }

    private var activeBinding: Binding<Bool> {
        Binding(
            get: { awake.isActive },
            set: { on in
                if on {
                    awake.startLastPick()
                } else if awake.isActive {
                    awake.toggle()
                }
            }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = defaultDuration == minutes
        return Button {
            defaultDuration = minutes
            UserDefaults.standard.set(false, forKey: DefaultsKey.keepAwakeSwitchUsesUntil)
        } label: {
            Text(DurationPicker.title(for: minutes, l10n.s))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Automation

    private var automationCard: some View {
        SettingsCard(title: automationStrings.automationSection) {
            Text(automationStrings.caption(requireAll: UserDefaults.standard
                .bool(forKey: DefaultsKey.keepAwakeAutomationRequireAll)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            KeepAwakeAutomationEditor()
            SettingsRow(symbol: "lock.fill", title: automationStrings.pauseWhenLockedToggle,
                        caption: automationStrings.pauseWhenLockedCaption) {
                Toggle(automationStrings.pauseWhenLockedToggle, isOn: $keepAwakePauseWhenLocked).labelsHidden()
            }
        }
    }

    // MARK: - Pointer

    private var pointerCard: some View {
        SettingsCard(title: l10n.s.keepAwakeMouseJiggle) {
            SettingsRow(symbol: "cursorarrow.motionlines", title: l10n.s.keepAwakeMouseJiggle,
                        caption: l10n.s.keepAwakeMouseJiggleCaption) {
                Toggle(l10n.s.keepAwakeMouseJiggle, isOn: $keepAwakeMouseJiggle).labelsHidden()
            }
            if keepAwakeMouseJiggle {
                Divider()
                HStack {
                    Text(l10n.s.keepAwakeMouseJiggleInterval)
                    Spacer()
                    KeepAwakeMouseJiggleIntervalPicker(selection: $keepAwakeMouseJiggleInterval)
                }
                if !AccessibilityPermission.isGranted {
                    HStack(spacing: 8) {
                        Label("\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(l10n.s.permissionRequest) {
                            AccessibilityPermission.request()
                        }
                        .controlSize(.small)
                        Button(l10n.s.permissionOpenSettings) {
                            AccessibilityPermission.openSettings()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Battery

    private var batteryCard: some View {
        SettingsCard(title: l10n.s.batteryProtectionSection) {
            SettingsRow(symbol: "battery.25percent", title: l10n.s.batteryDisableBelow,
                        caption: l10n.s.batteryProtectionCaption) {
                Picker(l10n.s.batteryDisableBelow, selection: $batteryLimit) {
                    Text(l10n.s.batteryNever).tag(0)
                    Text("5%").tag(5)
                    Text("10%").tag(10)
                    Text("15%").tag(15)
                    Text("20%").tag(20)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Closed lid

    private var clamshellCard: some View {
        SettingsCard(title: l10n.s.clamshellSection) {
            SettingsRow(symbol: "laptopcomputer", title: l10n.s.clamshellTitle, caption: clamshellCaption) {
                Toggle(l10n.s.clamshellTitle, isOn: $awake.clamshellPreferred)
                    .labelsHidden()
                    .disabled(awake.clamshellSetupInProgress)
            }
            if awake.clamshellPreferred {
                SettingsRow(symbol: "sun.min", title: l10n.s.dimScreenOnLidCloseTitle,
                            caption: l10n.s.dimScreenOnLidCloseCaption) {
                    Toggle(l10n.s.dimScreenOnLidCloseTitle, isOn: $awake.dimScreenOnLidClose).labelsHidden()
                }
            }
            Text(l10n.s.clamshellExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var clamshellCaption: String {
        if awake.clamshellSetupInProgress { return l10n.s.configuring }
        if awake.clamshellSetupFailed { return l10n.s.sudoersFailed }
        if awake.clamshellActive { return l10n.s.clamshellOnCaption }
        if awake.clamshellPreferred { return l10n.s.clamshellNeedsSession }
        return awake.passwordlessClamshell ? l10n.s.clamshellReady : l10n.s.clamshellNeedsPassword
    }

    // MARK: - Menu bar

    private var menuBarCard: some View {
        SettingsCard(title: l10n.s.menuBarSection) {
            KeepAwakeIconPicker(iconValue: $keepAwakeActiveIcon, tintValue: $keepAwakeIconTint)
        }
    }

    // MARK: - General

    private var generalCard: some View {
        SettingsCard(title: l10n.s.tabGeneral) {
            SettingsRow(symbol: "power", title: l10n.s.launchAtLogin, caption: loginError) {
                Toggle(l10n.s.launchAtLogin, isOn: loginBinding).labelsHidden()
            }
            SettingsRow(symbol: "globe", title: l10n.s.languageLabel) {
                Picker(l10n.s.languageLabel, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            Divider()
            SettingsRow(symbol: "command", title: l10n.s.hotkeyToggle, caption: l10n.s.hotkeyCaption) {
                Toggle(l10n.s.hotkeyToggle, isOn: $hotkeyEnabled)
                    .labelsHidden()
                    .onChange(of: hotkeyEnabled) { _, _ in hotkeys.syncWithPreferences() }
            }
            if hotkeyEnabled {
                HStack(spacing: 8) {
                    Text(recordingShortcut ? l10n.s.shortcutPressKeys : l10n.s.shortcutRecording)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    ShortcutRecorderField(shortcut: shortcut,
                                          placeholder: l10n.s.shortcutPressKeys) { newValue in
                        if let newValue {
                            shortcut = newValue
                            UserDefaults.standard.set(newValue.storageValue,
                                                      forKey: DefaultsKey.keepAwakeShortcut)
                        } else {
                            UserDefaults.standard.removeObject(forKey: DefaultsKey.keepAwakeShortcut)
                            shortcut = .keepAwakeDefault
                        }
                        hotkeys.syncWithPreferences()
                    } onRecordingChanged: { recording in
                        recordingShortcut = recording
                    }
                    .frame(width: 130, height: 24)
                    Button(l10n.s.shortcutReset) {
                        UserDefaults.standard.set(KeepAwakeShortcut.keepAwakeDefault.storageValue,
                                                  forKey: DefaultsKey.keepAwakeShortcut)
                        shortcut = .keepAwakeDefault
                        hotkeys.syncWithPreferences()
                    }
                    .controlSize(.small)
                }
                if hotkeys.registrationFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { loginRegistration == .enabled },
            set: { setLaunchAtLogin($0) }
        )
    }

    private func refreshLaunchAtLogin() {
        LaunchAtLogin.refresh { registration in
            loginRegistration = registration
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        LaunchAtLogin.setEnabled(enabled) { registration, error in
            loginRegistration = registration
            loginError = error?.localizedDescription
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { l10n.language },
            set: { l10n.language = $0 }
        )
    }

    // MARK: - About

    private var aboutCard: some View {
        SettingsCard(title: l10n.s.menuAbout) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(l10n.s.versionPrefix) \(AppInfo.version)")
                    .font(.subheadline.weight(.medium))
                Text(l10n.s.aboutDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link(l10n.s.viewOnGitHub, destination: AppInfo.repositoryURL)
                    .font(.caption)
            }
        }
    }

    // MARK: - Strings

    private var automationStrings: KeepAwakeAutomationStrings {
        KeepAwakeStrings.automation(l10n.language)
    }

    private var displaySleepStrings: KeepAwakeDisplaySleepStrings {
        KeepAwakeStrings.displaySleep(l10n.language)
    }
}

// MARK: - Shared layout

struct SettingsCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
        }
    }
}

struct SettingsRow<Control: View>: View {
    let symbol: String
    let title: String
    var caption: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5))
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control
        }
    }
}

extension SettingsRow where Control == EmptyView {
    init(symbol: String, title: String, caption: String? = nil) {
        self.init(symbol: symbol, title: title, caption: caption) { EmptyView() }
    }
}
