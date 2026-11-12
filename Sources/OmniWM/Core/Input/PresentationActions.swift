// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Carbon
import Foundation
import OmniWMIPC

extension IPCPresentationCommand {
    func actionDisplayName() -> LocalizedStringResource {
        switch self {
        case .overview: LocalizedStringResource(
                "command.presentation.overview", defaultValue: "Toggle Overview", table: "Commands", bundle: .omniWM
            )
        case .systemStats: LocalizedStringResource(
                "command.presentation.systemStats", defaultValue: "Toggle System Stats", table: "Commands",
                bundle: .omniWM
            )
        case .quakeTerminal: LocalizedStringResource(
                "command.presentation.quakeTerminal", defaultValue: "Toggle Quake Terminal", table: "Commands",
                bundle: .omniWM
            )
        case .workspaceBar: LocalizedStringResource(
                "command.presentation.workspaceBar", defaultValue: "Toggle Workspace Bar", table: "Commands",
                bundle: .omniWM
            )
        case .hiddenBar: LocalizedStringResource(
                "command.presentation.hiddenBar", defaultValue: "Toggle Hidden Icons Panel", table: "Commands",
                bundle: .omniWM
            )
        case .borders: LocalizedStringResource(
                "command.presentation.borders", defaultValue: "Toggle Borders", table: "Commands", bundle: .omniWM
            )
        case .newWindowJoinNewColumn,
             .newWindowJoinTabbed,
             .newWindowJoinStacked,
             .cycleNewWindowJoin,
             .cyclePaddingPreset,
             .cycleNewWindowPlacement,
             .newWindowPlacementRight,
             .newWindowPlacementLeft,
             .newWindowPlacementFirst,
             .newWindowPlacementLast:
            forkActionDisplayName()
        }
    }

    func actionSpec() -> ActionSpec {
        let id: String
        let keywords: [String]
        var binding = KeyBinding.unassigned
        switch self {
        case .overview:
            id = "toggleOverview"
            keywords = ["overview"]
            binding = KeyBinding(keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(optionKey | shiftKey))
        case .systemStats:
            id = "toggleSystemStats"
            keywords = ["stats", "system", "cpu", "memory", "gpu", "disk", "fetch"]
            binding = .unassigned
        case .quakeTerminal:
            id = "toggleQuakeTerminal"
            keywords = ["quake", "terminal"]
            binding = KeyBinding(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey))
        case .workspaceBar:
            id = "toggleWorkspaceBarVisibility"
            keywords = ["workspace bar", "bar"]
            binding = .unassigned
        case .hiddenBar:
            id = "toggleHiddenBarPanel"
            keywords = ["hidden bar", "icons", "menu bar"]
            binding = .unassigned
        case .borders:
            id = "toggleBorders"
            keywords = ["border", "borders", "outline"]
        case .newWindowJoinNewColumn,
             .newWindowJoinTabbed,
             .newWindowJoinStacked,
             .cycleNewWindowJoin,
             .cyclePaddingPreset,
             .cycleNewWindowPlacement,
             .newWindowPlacementRight,
             .newWindowPlacementLeft,
             .newWindowPlacementFirst,
             .newWindowPlacementLast:
            (id, keywords) = forkActionSpecFields()
        }
        return ActionCatalog.action(
            id: id,
            command: .presentation(self),
            category: .focus,
            binding: binding,
            keywords: keywords
        )
    }
}
