// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import os.log
import UserNotifications

/// The two notifications this app posts: a session that ran out its timer, and
/// battery protection ending one to protect the charge.
///
/// UserNotifications is loaded on first use rather than at launch. Merely
/// asking the system for the shared center opens a connection to
/// `usernotificationsd`, which an idle menu bar app should not need; starting
/// a session is the first moment a notification could ever be posted.
enum Notifier {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint-coffee",
                                    category: "notifications")

    /// Held strongly: UNUserNotificationCenter keeps its delegate weakly.
    private static var presenter: NotificationPresenter?
    private static var center: UNUserNotificationCenter?

    private static func resolvedCenter() -> UNUserNotificationCenter? {
        // UNUserNotificationCenter aborts in a process without a bundle, which
        // keeps ad-hoc runs of the bare binary alive.
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        if let center { return center }
        let resolved = UNUserNotificationCenter.current()
        let presenter = NotificationPresenter()
        resolved.delegate = presenter
        Self.presenter = presenter
        center = resolved
        return resolved
    }

    static func requestPermission() {
        guard let center = resolvedCenter() else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                log.notice("notification authorization not granted")
            }
        }
    }

    static func post(title: String, body: String) {
        guard let center = resolvedCenter() else { return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                log.notice("notification dropped: authorization status \(settings.authorizationStatus.rawValue)")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    log.error("notification delivery failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}

/// Shows a notification that arrives while the app is in front.
private final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
