// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

struct PersistedScratchpadMembership: Codable, Equatable, Sendable {
    var bundleId: String
    var pid: Int32
    var windowId: Int
    var title: String?
    var slot: Int

    func matches(bundleId: String?, pid: Int32, windowId: Int) -> Bool {
        self.bundleId == bundleId && self.pid == pid && self.windowId == windowId
    }

    static func titleMatch(
        in memberships: [PersistedScratchpadMembership],
        bundleId: String?,
        title: String?
    ) -> PersistedScratchpadMembership? {
        guard let bundleId, let title, !title.isEmpty else { return nil }
        let candidates = memberships.filter { $0.bundleId == bundleId && $0.title == title }
        return candidates.count == 1 ? candidates.first : nil
    }
}
