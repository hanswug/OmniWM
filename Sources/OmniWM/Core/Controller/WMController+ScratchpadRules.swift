// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Foundation

extension WMController {
    func applyScratchpadRule(to token: WindowToken) {
        guard var hints = workspaceManager.admissionHints(for: token),
              let slot = hints.scratchpadSlot,
              let index = ScratchpadIndex(slot)
        else { return }
        hints.scratchpadSlot = nil
        workspaceManager.updateAdmissionHints(hints, for: token)
        guard workspaceManager.scratchpadIndex(for: token) == nil else { return }
        let revealsOnArrival = layoutRefreshController.layoutState.hasCompletedInitialRefresh
        DispatchQueue.main.async { [weak self] in
            self?.assignScratchpadRuleWindow(token, to: index, reveals: revealsOnArrival, retries: 3)
        }
    }

    func assignScratchpadRuleWindow(_ token: WindowToken, to index: ScratchpadIndex, reveals: Bool, retries: Int) {
        guard workspaceManager.entry(for: token) != nil,
              workspaceManager.scratchpadIndex(for: token) == nil
        else { return }
        let monitor = monitorForInteraction()
        guard assignWindowToScratchpad(token, to: index, preferredMonitor: monitor) == .executed else {
            guard retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.assignScratchpadRuleWindow(token, to: index, reveals: reveals, retries: retries - 1)
            }
            return
        }
        guard reveals, workspaceManager.revealedScratchpadIndex() != index else { return }
        revealScratchpadWindow(token, index: index, on: monitor?.id)
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
