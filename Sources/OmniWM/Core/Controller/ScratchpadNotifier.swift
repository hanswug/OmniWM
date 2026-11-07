// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import UserNotifications

@MainActor
enum ScratchpadNotifier {
    static var post: @MainActor (_ title: String, _ body: String) -> Void = { deliver(title: $0, body: $1) }

    private static func deliver(title: String, body: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try? await center.add(UNNotificationRequest(
                identifier: "scratchpad.\(title)",
                content: content,
                trigger: nil
            ))
        }
    }
}
