// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The menu bar popover: what Keep Awake is doing right now, the presets that
/// start a session, the options that shape one, and the way into Settings.
struct KeepAwakePanelView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared

    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration = 0
    @AppStorage(DefaultsKey.keepAwakeAutoStart) private var keepAwakeAutoStart = false
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var keepAwakeAllowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakeExternalDisplay) private var keepAwakeExternalDisplay = false
    @AppStorage(DefaultsKey.keepAwakeConnectedToPower) private var keepAwakeConnectedToPower = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var keepAwakePauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeIconTint) private var keepAwakeIconTint = KeepAwakeIconTint.orange.rawValue
    @AppStorage(DefaultsKey.keepAwakeActiveIcon) private var keepAwakeActiveIcon = KeepAwakeActiveIcon.coffee.rawValue
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var keepAwakeMouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var keepAwakeMouseJiggleInterval = 5
    /// The last started end time, which the popover opens on.
    @AppStorage(DefaultsKey.keepAwakeUntilTime) private var savedUntilTime = 0.0

    @State private var optionsExpanded = false
    @State private var automationExpanded = false
    /// An edit not started yet; only starting saves it.
    @State private var untilDraft: Date?

    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    /// Only the hour and minute matter; `resolvedUntilDate` picks the next one.
    private var untilTime: Binding<Date> {
        Binding(
            get: {
                untilDraft ?? (savedUntilTime > 0
                    ? Date(timeIntervalSinceReferenceDate: savedUntilTime)
                    : Date().addingTimeInterval(3600))
            },
            set: { untilDraft = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            durationRow

            TimelineView(.periodic(from: .now, by: 30)) { _ in
                if let percent = awake.batteryProtectionPercent() {
                    Label(batteryNote(percent), systemImage: "battery.25percent")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(chipHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            optionsDisclosure

            Divider()

            clamshellRow

            Divider()

            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration)
            keepAwakeIconTint = Defaults.sanitizedKeepAwakeIconTint(keepAwakeIconTint).rawValue
            keepAwakeActiveIcon = Defaults.sanitizedKeepAwakeActiveIcon(keepAwakeActiveIcon).rawValue
            keepAwakeMouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(keepAwakeMouseJiggleInterval)
            awake.refreshPasswordlessStatus()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.s.keepAwakeTitle)
                    .font(.system(size: 12, weight: .semibold))
                statusLine
            }
            Spacer(minLength: 6)
            Toggle(l10n.s.keepAwakeTitle, isOn: activeBinding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var statusLine: some View {
        Group {
            if awake.isActive {
                if awake.sessionTrigger == .automation {
                    Text(automationStrings.activeStatus(for: awake.activeAutomationConditions))
                } else if let end = awake.endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(l10n.s.keepAwakeEndsIn) \(Self.remainingText(until: end))")
                    }
                } else {
                    Text(l10n.s.keepAwakeUntilDisabled)
                }
            } else {
                Text(l10n.s.keepAwakeNormalRules)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
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

    // MARK: - Presets

    private var durationRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(DurationPicker.choices, id: \.self, content: durationChip)
                untilChip
            }
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(DurationPicker.choices.prefix(4), id: \.self, content: durationChip)
                }
                HStack(spacing: 4) {
                    ForEach(DurationPicker.choices.dropFirst(4), id: \.self, content: durationChip)
                    untilChip
                }
            }
        }
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = manualSession && awake.sessionMinutes == minutes
        return Button {
            if selected {
                awake.toggle()
            } else {
                awake.activate(minutes: minutes)
            }
        } label: {
            ZStack {
                Text(DurationPicker.shortTitle(for: minutes, l10n.s, l10n.language))
                if minutes > 0 {
                    Text("0:00:00").hidden()
                }
            }
            .opacity(selected && awake.endDate != nil ? 0 : 1)
            .overlay {
                if selected, let end = awake.endDate {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Self.countdownText(until: end))
                            .fixedSize()
                    }
                }
            }
        }
        .buttonStyle(KeepAwakeChipStyle(isSelected: selected))
        .accessibilityLabel(DurationPicker.title(for: minutes, l10n.s))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var untilChip: some View {
        KeepAwakeEndTimePicker(
            selection: untilTime,
            activeEnd: manualSession && awake.sessionMinutes == nil ? awake.endDate : nil,
            onStop: { awake.toggle() }
        ) {
            awake.activate(until: KeepAwakeAutomationSupport.resolvedUntilDate(
                picked: untilTime.wrappedValue, now: Date()))
            untilDraft = nil
        }
    }

    private var manualSession: Bool {
        awake.isActive && awake.sessionTrigger == .manual
    }

    /// "58:12" or "1:05:12" for the highlighted chip.
    static func countdownText(until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSinceNow))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    static func remainingText(until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSinceNow))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1)) min"
    }

    // MARK: - Options

    private var optionsDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                optionsExpanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: optionsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(l10n.s.keepAwakeOptions)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if optionsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    KeepAwakeIconPicker(iconValue: $keepAwakeActiveIcon,
                                        tintValue: $keepAwakeIconTint,
                                        compact: true)
                    compactOptionToggle(icon: "display",
                                        title: displaySleepStrings.allowDisplaySleep,
                                        isOn: $keepAwakeAllowDisplaySleep)
                    compactOptionToggle(icon: "play.circle",
                                        title: l10n.s.keepAwakeAutoStart,
                                        isOn: $keepAwakeAutoStart)
                    automationDisclosure
                    compactOptionToggle(icon: "cursorarrow.motionlines",
                                        title: l10n.s.keepAwakeMouseJiggle,
                                        isOn: $keepAwakeMouseJiggle,
                                        errorText: mouseJiggleNeedsAccessibility ? mouseJiggleCaption : nil)
                    if keepAwakeMouseJiggle {
                        HStack(spacing: 8) {
                            Text(l10n.s.keepAwakeMouseJiggleInterval)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            KeepAwakeMouseJiggleIntervalPicker(selection: $keepAwakeMouseJiggleInterval)
                        }
                        .padding(.leading, 22)
                        if mouseJiggleNeedsAccessibility {
                            Button(l10n.s.permissionRequest) {
                                AccessibilityPermission.request()
                                AccessibilityPermission.openSettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.leading, 22)
                        }
                    }
                }
                .padding(.leading, 19)
            }
        }
    }

    private var automationDisclosure: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                automationExpanded.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 15)
                    Text(automationStrings.automationSection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    automationSummaryBadges
                    Image(systemName: automationExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if automationExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    KeepAwakeAutomationEditor(compact: true)
                    compactOptionToggle(icon: "lock.fill",
                                        title: automationStrings.pauseWhenLockedToggle,
                                        isOn: $keepAwakePauseWhenLocked)
                }
                .padding(.leading, 22)
            }
        }
    }

    @ViewBuilder
    private var automationSummaryBadges: some View {
        if !keepAwakeExternalDisplay, !keepAwakeConnectedToPower, !keepAwakePauseWhenLocked {
            Text(automationStrings.automationOff)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 4) {
                if keepAwakeExternalDisplay { automationSystemBadge("display") }
                if keepAwakeConnectedToPower { automationSystemBadge("powerplug.fill") }
                if keepAwakePauseWhenLocked { automationSystemBadge("lock.fill") }
            }
        }
    }

    private func automationSystemBadge(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 17, height: 17)
            .background(Circle().fill(Color.accentColor.opacity(0.12)))
    }

    private func compactOptionToggle(icon: String,
                                     title: String,
                                     isOn: Binding<Bool>,
                                     errorText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle(title, isOn: isOn)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            if let errorText {
                Text(errorText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.red)
                    .padding(.leading, 22)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var mouseJiggleNeedsAccessibility: Bool {
        keepAwakeMouseJiggle && !AccessibilityPermission.isGranted
    }

    private var mouseJiggleCaption: String {
        "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)"
    }

    // MARK: - Closed lid

    private var clamshellRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.s.clamshellTitle)
                        .font(.system(size: 11.5, weight: .medium))
                    Text(clamshellCaption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(awake.clamshellSetupFailed ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle(l10n.s.clamshellTitle, isOn: $awake.clamshellPreferred)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(awake.clamshellSetupInProgress)
            }
            if awake.clamshellPreferred {
                HStack(spacing: 8) {
                    Image(systemName: "sun.min")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(l10n.s.dimScreenOnLidCloseTitle)
                        .font(.system(size: 11))
                    Spacer(minLength: 8)
                    Toggle(l10n.s.dimScreenOnLidCloseTitle, isOn: $awake.dimScreenOnLidClose)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                .padding(.leading, 24)
            }
        }
    }

    private var clamshellCaption: String {
        if awake.clamshellSetupInProgress { return l10n.s.configuring }
        if awake.clamshellSetupFailed { return l10n.s.sudoersFailed }
        if awake.clamshellActive { return l10n.s.clamshellOnCaption }
        if awake.clamshellPreferred { return l10n.s.clamshellNeedsSession }
        return awake.passwordlessClamshell ? l10n.s.clamshellReady : l10n.s.clamshellNeedsPassword
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button(l10n.s.panelSettings) { onOpenSettings() }
                .buttonStyle(.borderless)
                .controlSize(.small)
            Spacer(minLength: 4)
            if UserDefaults.standard.bool(forKey: DefaultsKey.hotkeyEnabled) {
                Text("\(l10n.s.panelHotkeyHint) \(shortcutDisplay)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button(l10n.s.panelQuit) { onQuit() }
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
    }

    private var shortcutDisplay: String {
        KeepAwakeShortcut.saved(for: DefaultsKey.keepAwakeShortcut,
                                fallback: .keepAwakeDefault).displayString
    }

    // MARK: - Strings that vary with the panel state

    private var automationStrings: KeepAwakeAutomationStrings {
        KeepAwakeStrings.automation(l10n.language)
    }

    private var displaySleepStrings: KeepAwakeDisplaySleepStrings {
        KeepAwakeStrings.displaySleep(l10n.language)
    }

    private func batteryNote(_ percent: Int) -> String {
        switch l10n.language {
        case .enUS: return "Battery at \(percent)%. Plug in or lower the battery limit to start"
        case .ptBR: return "Bateria em \(percent)%. Conecte o carregador ou reduza o limite de bateria para iniciar"
        case .tr: return "Pil %\(percent). Başlatmak için şarja takın veya pil sınırını düşürün"
        case .ru: return "Заряд \(percent)%. Подключите питание или снизьте порог заряда, чтобы начать"
        case .es: return "Batería al \(percent) %. Conecta el cargador o baja el límite de batería para empezar"
        case .sk: return "Batéria na \(percent) %. Pripojte napájanie alebo znížte limit batérie a spustite"
        case .de: return "Batterie bei \(percent) %. Zum Starten Netzteil anschließen oder Batteriegrenze senken"
        case .fr: return "Batterie à \(percent)\u{00A0}%. Brancher le chargeur ou baisser la limite de batterie pour démarrer"
        case .it: return "Batteria al \(percent)%. Collega l’alimentatore o abbassa il limite della batteria per iniziare"
        case .ja: return "バッテリー残量 \(percent)%。電源に接続するかバッテリーの下限を下げると開始できます"
        case .ko: return "배터리 \(percent)%. 전원을 연결하거나 배터리 한도를 낮추면 시작할 수 있습니다"
        case .uk: return "Заряд \(percent)%. Підключіть живлення або знизьте поріг заряду, щоб почати"
        case .zhHans: return "电量 \(percent)%。接通电源或调低电量下限即可开始"
        case .zhTW, .zhHK: return "電量 \(percent)%。接上電源或調低電量下限即可開始"
        }
    }

    private var chipHint: String {
        switch l10n.language {
        case .enUS: return "Click a chip to start. Click it again to stop"
        case .ptBR: return "Clique em um chip para iniciar. Clique de novo para parar"
        case .tr: return "Başlatmak için bir çipe tıklayın. Durdurmak için tekrar tıklayın"
        case .ru: return "Нажмите на чип, чтобы начать. Нажмите снова, чтобы остановить"
        case .es: return "Haz clic en un chip para empezar. Vuelve a hacer clic para detener"
        case .sk: return "Kliknutím na čip spustíte. Ďalším kliknutím zastavíte"
        case .de: return "Chip anklicken zum Starten. Erneut anklicken zum Beenden"
        case .fr: return "Cliquer sur une puce pour démarrer. Cliquer à nouveau pour arrêter"
        case .it: return "Fai clic su un chip per iniziare. Fai di nuovo clic per fermare"
        case .ja: return "チップをクリックで開始、もう一度クリックで停止"
        case .ko: return "칩을 클릭하면 시작하고, 다시 클릭하면 멈춥니다"
        case .uk: return "Натисніть на чип, щоб почати. Натисніть ще раз, щоб зупинити"
        case .zhHans: return "点按一个标签即可开始，再次点按即可停止"
        case .zhTW, .zhHK: return "點按一個標籤即可開始，再次點按即可停止"
        }
    }
}
