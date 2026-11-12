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
        case .newWindowJoinNewColumn: LocalizedStringResource(
                "command.presentation.newWindowJoinNewColumn", defaultValue: "New Windows: New Column",
                table: "Commands", bundle: .omniWM
            )
        case .newWindowJoinTabbed: LocalizedStringResource(
                "command.presentation.newWindowJoinTabbed", defaultValue: "New Windows: Tabbed",
                table: "Commands", bundle: .omniWM
            )
        case .newWindowJoinStacked: LocalizedStringResource(
                "command.presentation.newWindowJoinStacked", defaultValue: "New Windows: Stacked",
                table: "Commands", bundle: .omniWM
            )
        case .cycleNewWindowJoin: LocalizedStringResource(
                "command.presentation.cycleNewWindowJoin", defaultValue: "Cycle New Window Join Mode",
                table: "Commands", bundle: .omniWM
            )
        case .cyclePaddingPreset: LocalizedStringResource(
                "command.presentation.cyclePaddingPreset", defaultValue: "Cycle Padding Preset", table: "Commands",
                bundle: .omniWM
            )
        case .cycleNewWindowPlacement: LocalizedStringResource(
                "command.presentation.cycleNewWindowPlacement", defaultValue: "Cycle New Window Placement",
                table: "Commands",
                bundle: .omniWM
            )
        case .newWindowPlacementRight: LocalizedStringResource(
                "command.presentation.newWindowPlacementRight", defaultValue: "New Windows: Open Right",
                table: "Commands",
                bundle: .omniWM
            )
        case .newWindowPlacementLeft: LocalizedStringResource(
                "command.presentation.newWindowPlacementLeft", defaultValue: "New Windows: Open Left",
                table: "Commands",
                bundle: .omniWM
            )
        case .newWindowPlacementFirst: LocalizedStringResource(
                "command.presentation.newWindowPlacementFirst", defaultValue: "New Windows: Open First",
                table: "Commands",
                bundle: .omniWM
            )
        case .newWindowPlacementLast: LocalizedStringResource(
                "command.presentation.newWindowPlacementLast", defaultValue: "New Windows: Open Last",
                table: "Commands",
                bundle: .omniWM
            )
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
        case .newWindowJoinNewColumn:
            id = "newWindowJoin.newColumn"
            keywords = ["new window", "join", "column"]
        case .newWindowJoinTabbed:
            id = "newWindowJoin.tabbed"
            keywords = ["new window", "join", "tab", "tabbed"]
        case .newWindowJoinStacked:
            id = "newWindowJoin.stacked"
            keywords = ["new window", "join", "stack", "stacked"]
        case .cycleNewWindowJoin:
            id = "cycleNewWindowJoin"
            keywords = ["new window", "join", "cycle", "tab", "stack"]
        case .cyclePaddingPreset:
            id = "cyclePaddingPreset"
            keywords = ["padding", "preset", "gaps", "cycle"]
        case .cycleNewWindowPlacement:
            id = "cycleNewWindowPlacement"
            keywords = ["new window", "placement", "cycle"]
        case .newWindowPlacementRight:
            id = "newWindowPlacement.right"
            keywords = ["new window", "placement", "right"]
        case .newWindowPlacementLeft:
            id = "newWindowPlacement.left"
            keywords = ["new window", "placement", "left"]
        case .newWindowPlacementFirst:
            id = "newWindowPlacement.first"
            keywords = ["new window", "placement", "first"]
        case .newWindowPlacementLast:
            id = "newWindowPlacement.last"
            keywords = ["new window", "placement", "last"]
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
