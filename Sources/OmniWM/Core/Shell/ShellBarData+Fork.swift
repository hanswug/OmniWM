// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

struct ShellBarForkStatus: Equatable, Sendable {
    struct FocusedWindow: Equatable, Sendable {
        let pid: Int32
        let app: String
        let fullscreen: Bool
        let fullSpan: Bool
    }

    struct PaddingPreset: Equatable, Sendable {
        let name: String
        let top: Double
        let bottom: Double
        let left: Double
        let right: Double
        let active: Bool
    }

    var layout: ActiveLayoutKind = .niri
    var visibleContainers = 1
    var focusedWindow: FocusedWindow?
    var newWindowPlacement = NewWindowPlacement.right.rawValue
    var newWindowJoin = NewWindowJoin.newColumn.rawValue
    var paddingPresets: [PaddingPreset] = []
    var ownPadding: String?

    var paddingPreset: String? {
        paddingPresets.first(where: \.active)?.name
    }

    func write(to writer: inout ShellValueWriter) {
        writer.map(8)
        writer.key("layout")
        writer.string(layout.rawValue)
        writer.key("visibleContainers")
        writer.number(Double(visibleContainers))
        writer.key("focusedWindow")
        if let focusedWindow {
            writer.map(4)
            writer.key("pid")
            writer.number(Double(focusedWindow.pid))
            writer.key("app")
            writer.string(focusedWindow.app)
            writer.key("fullscreen")
            writer.bool(focusedWindow.fullscreen)
            writer.key("fullSpan")
            writer.bool(focusedWindow.fullSpan)
        } else {
            writer.null()
        }
        writer.key("newWindowPlacement")
        writer.string(newWindowPlacement)
        writer.key("newWindowJoin")
        writer.string(newWindowJoin)
        writer.key("paddingPreset")
        if let paddingPreset {
            writer.string(paddingPreset)
        } else {
            writer.null()
        }
        writer.key("ownPadding")
        if let ownPadding {
            writer.string(ownPadding)
        } else {
            writer.null()
        }
        writer.key("paddingPresets")
        writePresets(to: &writer)
    }

    private func writePresets(to writer: inout ShellValueWriter) {
        writer.array(paddingPresets.count)
        for preset in paddingPresets {
            writer.map(6)
            writer.key("name")
            writer.string(preset.name)
            writer.key("top")
            writer.number(preset.top)
            writer.key("bottom")
            writer.number(preset.bottom)
            writer.key("left")
            writer.number(preset.left)
            writer.key("right")
            writer.number(preset.right)
            writer.key("active")
            writer.bool(preset.active)
        }
    }
}

extension WMController {
    func ownPaddingLabel(for monitor: Monitor) -> String? {
        guard let override = settings.gaps.settings(for: monitor),
              override.outerGapLeft != nil || override.outerGapRight != nil
              || override.outerGapTop != nil || override.outerGapBottom != nil
        else { return nil }
        return monitor.name.hasPrefix("Built-in") ? "Built-in" : monitor.name
    }

    func shellForkStatus(on monitorId: Monitor.ID) -> ShellBarForkStatus {
        var status = ShellBarForkStatus()
        status.visibleContainers = settings.niri.visibleContainerCount
        status.ownPadding = workspaceManager.monitors.first { $0.id == monitorId }.flatMap(ownPaddingLabel(for:))
        if let workspaceId = workspaceManager.visibleWorkspaceId(on: monitorId) {
            status.layout = workspaceManager.activeLayoutKind(for: workspaceId)
            if let engine = niriEngine {
                status.visibleContainers = engine.effectiveVisibleContainerCount(in: workspaceId)
            }
        }
        let layout = focusedWindowLayoutState()
        if let token = layout.token {
            status.focusedWindow = ShellBarForkStatus.FocusedWindow(
                pid: token.pid,
                app: resolvedAppInfo(for: token.pid)?.name ?? "",
                fullscreen: layout.isFullscreen,
                fullSpan: layout.isContainerFullPrimarySpan
            )
        }
        status.newWindowPlacement = settings.niri.newWindowPlacement.rawValue
        status.newWindowJoin = settings.niri.newWindowJoin.rawValue
        let active = settings.gaps.activePaddingPresetIndex
        status.paddingPresets = settings.gaps.paddingPresets.enumerated().map { index, preset in
            ShellBarForkStatus.PaddingPreset(
                name: preset.name,
                top: preset.top,
                bottom: preset.bottom,
                left: preset.left,
                right: preset.right,
                active: index == active
            )
        }
        return status
    }
}
