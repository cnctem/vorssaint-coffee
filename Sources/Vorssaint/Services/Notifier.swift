// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import os.log
import UserNotifications

/// The two notifications Always Awake posts: a session that ran out its
/// timer, and battery protection ending one to protect the charge.
enum Notifier {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "notifications")

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                log.notice("notification authorization not granted")
            }
        }
    }

    static func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
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
