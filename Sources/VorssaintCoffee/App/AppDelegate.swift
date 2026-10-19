// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusController: StatusItemController!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var askedForNotificationPermission = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Service Management is loaded only when the user actually asked for a
        // login item; a launch that never uses it should not pay for it.
        if UserDefaults.standard.bool(forKey: DefaultsKey.launchAtLoginWanted) {
            LaunchAtLogin.repairAtStartup()
        }

        statusController = StatusItemController()
        statusController.onLeftClick = { [weak self] in self?.togglePopover() }
        statusController.onRightClick = { [weak self] button in
            guard let self else { return }
            if UserDefaults.standard.bool(forKey: DefaultsKey.keepAwakeRightClickToggle) {
                KeepAwakeManager.shared.toggle()
            } else {
                self.showContextMenu(from: button)
            }
        }

        setUpPopover()

        KeepAwakeManager.shared.onSessionEnded = { reason in
            let strings = L10n.shared.s
            switch reason {
            case .timer:
                Notifier.post(title: strings.notifySessionEndedTitle, body: strings.notifySessionEndedBody)
            case .battery:
                Notifier.post(title: strings.notifyBatteryTitle, body: strings.notifyBatteryBody)
            default:
                break
            }
        }

        HotkeyManager.shared.onActivate = { KeepAwakeManager.shared.toggle() }
        HotkeyManager.shared.syncWithPreferences()

        KeepAwakeManager.shared.recoverIfNeeded {
            KeepAwakeManager.shared.activateOnLaunchIfNeeded()
        }

        // The notification permission is asked the first time a session starts,
        // not at launch: a notification can only ever follow a session, and an
        // idle menu bar app has no reason to open the notification service.
        KeepAwakeManager.shared.$isActive
            .filter { $0 }
            .prefix(1)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.askedForNotificationPermission else { return }
                self.askedForNotificationPermission = true
                Notifier.requestPermission()
            }
            .store(in: &cancellables)

        L10n.shared.$language
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.settingsWindow != nil else { return }
                self.installMainMenu()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeepAwakeManager.shared.deactivate(reason: .quit)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    /// Opening the app again while it runs forces the menu bar icon back and
    /// pops the panel, so a lost icon is never a dead end.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusController?.recreateStatusItem()
            if !self.popover.isShown { self.togglePopover() }
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    @objc private func appBecameActive() {
        KeepAwakeManager.shared.refreshPasswordlessStatus()
    }

    // MARK: - Main menu

    /// An accessory app gets no main menu, so the standard shortcuts
    /// (Cmd+H/M/W/Q and the Edit shortcuts) have no items to fire.
    private func installMainMenu() {
        let strings = L10n.shared.s
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: strings.menuSettings, action: #selector(openSettings),
                        keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: strings.menuHide, action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: strings.menuHideOthers,
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: strings.menuShowAll,
                        action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: strings.menuQuit, action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: strings.menuEdit)
        editMenu.addItem(withTitle: strings.menuUndo, action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: strings.menuRedo, action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: strings.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: strings.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: strings.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: strings.menuSelectAll, action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: strings.menuWindow)
        windowMenu.addItem(withTitle: strings.menuMinimize, action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: strings.menuClose, action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Panel

    private func setUpPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Builds the SwiftUI panel the first time it is actually shown. Creating
    /// the hosting controller at launch would load and lay out a view tree that
    /// most launches never display.
    private func ensurePopoverContent() {
        guard popover.contentViewController == nil else { return }
        let panel = KeepAwakePanelView(
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettingsWindow()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        let host = NSHostingController(rootView: panel)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusController?.button {
            ensurePopoverContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        NSApp.deactivate()
    }

    // MARK: - Context menu

    private func showContextMenu(from button: NSStatusBarButton?) {
        let menu = makeContextMenu()
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: (button?.bounds.height ?? 0) + 4),
                   in: button)
    }

    private func makeContextMenu() -> NSMenu {
        let strings = L10n.shared.s
        let manager = KeepAwakeManager.shared
        let menu = NSMenu()
        let toggle = menu.addItem(withTitle: manager.isActive ? strings.menuDisableAwake : strings.menuEnableAwake,
                                  action: #selector(toggleKeepAwake), keyEquivalent: "")
        toggle.target = self

        let activateItem = NSMenuItem(title: strings.menuActivateFor, action: nil, keyEquivalent: "")
        let activateMenu = NSMenu()
        for minutes in Defaults.allowedDurations {
            let title = minutes > 0
                ? DurationPicker.title(for: minutes, strings)
                : strings.indefinitely
            let item = NSMenuItem(title: title, action: #selector(activateFor(_:)), keyEquivalent: "")
            item.tag = minutes
            item.target = self
            activateMenu.addItem(item)
        }
        activateItem.submenu = activateMenu
        menu.addItem(activateItem)

        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: strings.menuSettings,
                                        action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        let aboutItem = menu.addItem(withTitle: strings.menuAbout,
                                     action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: strings.menuQuit,
                                    action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        return menu
    }

    @objc private func toggleKeepAwake() {
        KeepAwakeManager.shared.toggle()
    }

    @objc private func activateFor(_ sender: NSMenuItem) {
        KeepAwakeManager.shared.activate(minutes: sender.tag)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .credits: NSAttributedString(string: L10n.shared.s.aboutDescription,
                                         attributes: [.font: NSFont.systemFont(ofSize: 11)]),
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings

    @objc private func openSettings() {
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        // The standard shortcuts only matter while one of the app's own windows
        // is focused, so the main menu is built with the first one.
        installMainMenu()
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let strings = L10n.shared.s
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = strings.settingsTitle
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: KeepAwakeSettingsView())
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        settingsWindow = nil
        if !popover.isShown { NSApp.deactivate() }
    }
}
