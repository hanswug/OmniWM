// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import OmniWMIPC

enum ScratchpadMode: String, Codable, CaseIterable, Sendable {
    case persistent
    case volatile

    static func normalized(_ modes: [String: ScratchpadMode]) -> [String: ScratchpadMode] {
        modes.reduce(into: [:]) { normalized, entry in
            guard let index = Int(entry.key.trimmingCharacters(in: .whitespacesAndNewlines)),
                  IPCScratchpadSlots.range.contains(index)
            else { return }
            normalized[String(index)] = entry.value
        }
    }
}
