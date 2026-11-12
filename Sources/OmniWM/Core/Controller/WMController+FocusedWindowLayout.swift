// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation

struct FocusedWindowLayoutState: Equatable {
    let token: WindowToken?
    let isFullscreen: Bool
    let isContainerFullPrimarySpan: Bool
}

extension WMController {
    func focusedWindowLayoutState() -> FocusedWindowLayoutState {
        guard let token = workspaceManager.nativeManagedFocusToken else {
            return FocusedWindowLayoutState(token: nil, isFullscreen: false, isContainerFullPrimarySpan: false)
        }
        return FocusedWindowLayoutState(
            token: token,
            isFullscreen: isLayoutFullscreen(token),
            isContainerFullPrimarySpan: isContainerFullPrimarySpan(token)
        )
    }

    func isLayoutFullscreen(_ token: WindowToken) -> Bool {
        guard let workspaceId = workspaceManager.entry(for: token)?.workspaceId else { return false }
        return workspaceManager.layoutTopology(for: workspaceId).isFullscreen(token)
    }

    func isContainerFullPrimarySpan(_ token: WindowToken) -> Bool {
        guard let workspaceId = workspaceManager.entry(for: token)?.workspaceId,
              let engine = niriEngine,
              let node = engine.findNode(for: token, in: workspaceId),
              let column = engine.findColumn(containing: node, in: workspaceId)
        else { return false }
        return column.isFullWidth
    }

    func publishFocusIfFocusedWindowLayoutChanged() {
        noteFocusedWindowLayoutForFeedback()
        guard focusNotificationDispatcher.focusedWindowLayoutStateChanged(),
              let ipcApplicationBridge
        else { return }
        Task {
            await ipcApplicationBridge.publishEvent(.focus)
        }
    }
}
