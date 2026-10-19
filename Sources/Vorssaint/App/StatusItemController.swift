// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Owns the menu bar presence: the app glyph, the optional countdown title and
/// the tooltip. Click handling is delegated back to the AppDelegate.
final class StatusItemController {
    var onLeftClick: (() -> Void)?
    var onRightClick: ((NSStatusBarButton?) -> Void)?

    private(set) var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var titleTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?
    private static let mainAutosaveName = "VorssaintMenuBarItem"
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    var button: NSStatusBarButton? { statusItem.button }

    init() {
        installStatusItem()
        bind()
    }

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = Self.mainAutosaveName
        statusItem.behavior = []
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = KeepAwakeGlyph.image(active: KeepAwakeManager.shared.isActive)
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.alignment = .left
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refresh()
    }

    /// Tears the item down and builds a fresh one, for the rare case macOS
    /// drops the icon and re-opening the app has to bring it back.
    func recreateStatusItem() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        installStatusItem()
    }

    private func bind() {
        KeepAwakeManager.shared.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        KeepAwakeManager.shared.$endDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        L10n.shared.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        titleTimer?.invalidate()
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            onRightClick?(statusItem.button)
        } else {
            onLeftClick?()
        }
    }

    /// Updates the countdown title, the icon and the tooltip from the current
    /// session state.
    func refresh() {
        guard let button = statusItem.button else { return }
        let manager = KeepAwakeManager.shared
        let strings = L10n.shared.s
        let defaults = UserDefaults.standard

        syncTitleTimer(keepAwakeActive: manager.isActive,
                       showsCountdown: defaults.bool(forKey: DefaultsKey.showCountdown),
                       endDate: manager.endDate)

        var title = ""
        if manager.isActive, defaults.bool(forKey: DefaultsKey.showCountdown) {
            if let end = manager.endDate {
                let remaining = max(0, Int(end.timeIntervalSinceNow))
                let hours = remaining / 3600
                let minutes = (remaining % 3600) / 60
                title = hours > 0 ? String(format: " %d:%02d", hours, minutes)
                    : " \(max(minutes, 1)) min"
            } else {
                title = " ∞"
            }
        }
        if button.title != title { button.title = title }
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading

        let toolTip: String
        if manager.isActive {
            if manager.sessionTrigger == .automation {
                toolTip = KeepAwakeStrings.automation(L10n.shared.language)
                    .activeStatus(for: manager.activeAutomationConditions)
            } else if let end = manager.endDate {
                toolTip = "\(strings.statusActiveUntil) \(Self.timeFormatter.string(from: end))"
            } else {
                toolTip = strings.statusActiveIndefinite
            }
        } else {
            toolTip = strings.statusIdleTooltip
        }
        if button.toolTip != toolTip { button.toolTip = toolTip }

        updateIcon(active: manager.isActive, button: button)
    }

    private var renderedIconKey = ""

    private func updateIcon(active: Bool, button: NSStatusBarButton) {
        let key = [String(active), KeepAwakeIconTint.current.rawValue,
                   KeepAwakeActiveIcon.current.rawValue].joined(separator: "|")
        guard key != renderedIconKey else { return }
        renderedIconKey = key
        button.image = KeepAwakeGlyph.image(active: active)
    }

    private func syncTitleTimer(keepAwakeActive: Bool, showsCountdown: Bool, endDate: Date?) {
        let shouldRun = keepAwakeActive && showsCountdown && endDate != nil
        guard shouldRun else {
            titleTimer?.invalidate()
            titleTimer = nil
            return
        }
        guard titleTimer == nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }
}
