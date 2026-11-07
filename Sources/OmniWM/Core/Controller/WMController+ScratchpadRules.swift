// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Foundation

extension WMController {
    func applyScratchpadRule(to token: WindowToken) {
        guard var hints = workspaceManager.admissionHints(for: token),
              let slot = hints.scratchpadSlot,
              let index = ScratchpadIndex(slot)
        else {
            restoreRememberedScratchpad(for: token)
            return
        }
        hints.scratchpadSlot = nil
        workspaceManager.updateAdmissionHints(hints, for: token)
        guard workspaceManager.scratchpadIndex(for: token) == nil else { return }
        let revealsOnArrival = layoutRefreshController.layoutState.hasCompletedInitialRefresh
        unminimizeForScratchpad(token)
        DispatchQueue.main.async { [weak self] in
            self?.assignScratchpadRuleWindow(token, to: index, reveals: revealsOnArrival, retries: 3)
        }
    }

    func assignScratchpadRuleWindow(_ token: WindowToken, to index: ScratchpadIndex, reveals: Bool, retries: Int) {
        guard workspaceManager.entry(for: token) != nil,
              workspaceManager.scratchpadIndex(for: token) == nil
        else { return }
        let monitor = monitorForInteraction()
        if reveals {
            showSlotForArrival(index, on: monitor?.id)
        }
        guard assignWindowToScratchpad(token, to: index, preferredMonitor: monitor) == .executed else {
            guard retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.assignScratchpadRuleWindow(token, to: index, reveals: reveals, retries: retries - 1)
            }
            return
        }
        guard reveals else { return }
        if workspaceManager.revealedScratchpadIndex() != index {
            revealScratchpadWindow(token, index: index, on: monitor?.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.bringRevealedScratchpadWindowToFront(token, index: index)
        }
    }

    private func showSlotForArrival(_ index: ScratchpadIndex, on monitorId: Monitor.ID?) {
        guard workspaceManager.revealedScratchpadIndex() != index else { return }
        if !scratchpadEntries(in: index).isEmpty {
            toggleScratchpad(index, on: monitorId)
            return
        }
        if let revealed = workspaceManager.revealedScratchpadIndex() {
            toggleScratchpad(revealed, on: monitorId)
        }
        workspaceManager.setRevealedScratchpad(index)
    }

    func bringRevealedScratchpadWindowToFront(_ token: WindowToken, index: ScratchpadIndex) {
        guard workspaceManager.revealedScratchpadIndex() == index,
              workspaceManager.scratchpadIndex(for: token) == index,
              workspaceManager.hiddenState(for: token) == nil,
              let entry = workspaceManager.entry(for: token)
        else { return }
        performWindowOrdering(windowId: entry.windowId)
        focusWindow(token, origin: .keyboardOrProgrammatic)
    }
}

extension WMController {
    func notifyScratchpadUnavailable(_ index: ScratchpadIndex) {
        let label = settings.scratchpadLabel(for: index.rawValue).map { " · \($0)" } ?? ""
        let title = "Scratchpad \(index.rawValue)\(label)"
        let appNames = settings.appRules
            .filter { $0.validScratchpadSlot == index.rawValue }
            .map(Self.scratchpadRuleAppName)
        let body: String
        if !scratchpadEntries(in: index).isEmpty {
            body = "Couldn't show it right now."
        } else if appNames.isEmpty {
            body = "It's empty."
        } else {
            body = "No \(appNames.joined(separator: ", ")) window is open."
        }
        ScratchpadNotifier.post(title, body)
    }

    private static func scratchpadRuleAppName(_ rule: AppRule) -> String {
        guard rule.hasBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleId)
        else { return rule.displayLabel }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

struct ScratchpadQuitPlan {
    var minimize: [AXWindowRef] = []
    var close: [AXWindowRef] = []

    func apply() {
        let minimized = minimize.filter { AXWindowService.minimize($0) }.count
        let closed = close.filter { AXWindowService.pressCloseButton($0) }.count
        Log.ax.notice(
            "Scratchpad quit: minimized \(minimized)/\(minimize.count), closed \(closed)/\(close.count)"
        )
    }
}

extension WMController {
    func scratchpadQuitPlan() -> ScratchpadQuitPlan {
        var plan = ScratchpadQuitPlan()
        for entry in workspaceManager.allEntries() {
            guard let index = workspaceManager.scratchpadIndex(for: entry.token),
                  let axRef = entry.axRef else { continue }
            switch settings.scratchpadMode(for: index.rawValue) {
            case .persistent: plan.minimize.append(axRef)
            case .volatile: plan.close.append(axRef)
            case nil: continue
            }
        }
        return plan
    }
}

extension WMController {
    func rememberScratchpadMemberships() {
        settings.scratchpadMemberships = workspaceManager.allEntries().compactMap { entry in
            guard let index = workspaceManager.scratchpadIndex(for: entry.token),
                  settings.scratchpadMode(for: index.rawValue) == .persistent,
                  let metadata = workspaceManager.persistedRestoreMetadata(for: entry),
                  let bundleId = metadata.bundleId
            else { return nil }
            return PersistedScratchpadMembership(
                bundleId: bundleId,
                pid: entry.pid,
                windowId: entry.windowId,
                title: metadata.title,
                slot: index.rawValue
            )
        }
    }

    private func restoreRememberedScratchpad(for token: WindowToken) {
        var memberships = settings.scratchpadMemberships
        guard !memberships.isEmpty,
              workspaceManager.scratchpadIndex(for: token) == nil,
              let entry = workspaceManager.entry(for: token)
        else { return }
        let metadata = workspaceManager.persistedRestoreMetadata(for: entry)
        let match = memberships.first { $0.matches(
            bundleId: metadata?.bundleId,
            pid: entry.pid,
            windowId: entry.windowId
        ) }
            ?? PersistedScratchpadMembership.titleMatch(
                in: memberships,
                bundleId: metadata?.bundleId,
                title: metadata?.title
            )
        guard let match, let index = ScratchpadIndex(match.slot) else { return }
        memberships.removeAll { $0 == match }
        settings.scratchpadMemberships = memberships
        unminimizeForScratchpad(token)
        DispatchQueue.main.async { [weak self] in
            self?.assignScratchpadRuleWindow(token, to: index, reveals: false, retries: 3)
        }
    }
}

extension WMController {
    private func unminimizeForScratchpad(_ token: WindowToken) {
        guard let axRef = workspaceManager.entry(for: token)?.axRef,
              AXWindowService.isMinimized(axRef) == true
        else { return }
        _ = AXWindowService.unminimize(axRef)
    }
}
