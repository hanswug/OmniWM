// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
import OmniWMIPC

extension IPCPresentationCommand {
    func forkActionDisplayName() -> LocalizedStringResource {
        switch self {
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
        default:
            preconditionFailure("\(self) is not a fork presentation command")
        }
    }

    func forkActionSpecFields() -> (id: String, keywords: [String]) {
        switch self {
        case .newWindowJoinNewColumn:
            ("newWindowJoin.newColumn", ["new window", "join", "column"])
        case .newWindowJoinTabbed:
            ("newWindowJoin.tabbed", ["new window", "join", "tab", "tabbed"])
        case .newWindowJoinStacked:
            ("newWindowJoin.stacked", ["new window", "join", "stack", "stacked"])
        case .cycleNewWindowJoin:
            ("cycleNewWindowJoin", ["new window", "join", "cycle", "tab", "stack"])
        case .cyclePaddingPreset:
            ("cyclePaddingPreset", ["padding", "preset", "gaps", "cycle"])
        case .cycleNewWindowPlacement:
            ("cycleNewWindowPlacement", ["new window", "placement", "cycle"])
        case .newWindowPlacementRight:
            ("newWindowPlacement.right", ["new window", "placement", "right"])
        case .newWindowPlacementLeft:
            ("newWindowPlacement.left", ["new window", "placement", "left"])
        case .newWindowPlacementFirst:
            ("newWindowPlacement.first", ["new window", "placement", "first"])
        case .newWindowPlacementLast:
            ("newWindowPlacement.last", ["new window", "placement", "last"])
        default:
            preconditionFailure("\(self) is not a fork presentation command")
        }
    }
}
