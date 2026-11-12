// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Foundation
import OmniWMIPC

extension WMController {
    func updateMonitorOrientations() {
        var orientations: [Monitor.ID: Monitor.Orientation] = [:]
        for monitor in workspaceManager.monitors {
            orientations[monitor.id] = settings.monitors.effectiveOrientation(for: monitor)
        }
        workspaceManager.withEngineMutationScope {
            niriEngine?.updateMonitorOrientations(orientations)
        }
        layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
    }

    func updateMonitorNiriSettings() {
        guard niriEngine != nil else { return }
        niriLayoutHandler.refreshResolvedMonitorSettings(rebalanceChangedSpans: true)
        layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
    }

    func updateMonitorDwindleSettings() {
        guard dwindleEngine != nil else { return }
        workspaceManager.invalidateAllLayouts()
        layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
    }

    func updateMonitorGapSettings() {
        workspaceManager.invalidateNiriCachedPrimarySpans()
        workspaceManager.invalidateAllLayouts()
        layoutRefreshController.requestRelayout(reason: .monitorSettingsChanged)
        publishDisplayChanged()
    }

    func publishDisplayChanged() {
        guard let ipcApplicationBridge else { return }
        Task {
            await ipcApplicationBridge.publishEvent(.displayChanged)
        }
    }

    func updateWorkspaceConfig() {
        workspaceManager.applySettings()
        refreshStatusBar()
        syncMonitorsToNiriEngine()
        layoutRefreshController.requestRelayout(reason: .workspaceConfigChanged)
    }

    func rebuildAppRulesCache() {
        windowRuleEngine.rebuild(rules: settings.appRules)
    }

    func updateAppRules() {
        rebuildAppRulesCache()
        layoutRefreshController.requestFullRescan(reason: .appRulesChanged)
    }

    func enableNiriLayout(
        centerFocusedColumn: CenterFocusedColumn = .never,
        alwaysCenterSingleColumn: Bool = false
    ) {
        niriLayoutHandler.enableNiriLayout(
            centerFocusedColumn: centerFocusedColumn,
            alwaysCenterSingleColumn: alwaysCenterSingleColumn
        )
        niriEngine?.newWindowPlacement = settings.niri.newWindowPlacement
        niriEngine?.newWindowJoin = settings.niri.newWindowJoin
    }

    func syncMonitorsToNiriEngine() {
        niriLayoutHandler.syncMonitorsToNiriEngine()
    }

    func updateNiriConfig(
        visibleContainerCount: Int? = nil,
        infiniteLoop: Bool? = nil,
        centerFocusedColumn: CenterFocusedColumn? = nil,
        alwaysCenterSingleColumn: Bool? = nil,
        singleWindowFit: SingleWindowFit? = nil,
        edgeOverscroll: NiriEdgeOverscroll? = nil,
        containerPrimarySpanPresets: [Double]? = nil,
        defaultContainerPrimarySpan: Double?? = nil
    ) {
        niriLayoutHandler.updateNiriConfig(
            visibleContainerCount: visibleContainerCount,
            infiniteLoop: infiniteLoop,
            centerFocusedColumn: centerFocusedColumn,
            alwaysCenterSingleColumn: alwaysCenterSingleColumn,
            singleWindowFit: singleWindowFit,
            edgeOverscroll: edgeOverscroll,
            containerPrimarySpanPresets: containerPrimarySpanPresets,
            defaultContainerPrimarySpan: defaultContainerPrimarySpan
        )
    }

    func rebalanceNiriSizesForVisibleContainerCountChange(on monitorId: Monitor.ID? = nil) {
        niriLayoutHandler.balanceSizesAllWorkspaces(
            on: monitorId,
            onlyAutomaticSpans: true,
            fillsUnusedSpace: settings.niri.visibleContainerChangeAction == .reset
        )
    }

    func setVisibleContainerCount(_ count: Int) {
        guard settings.niri.visibleContainerCount != count else { return }
        settings.niri.visibleContainerCount = count
        updateNiriConfig(visibleContainerCount: count)
        rebalanceNiriSizesForVisibleContainerCountChange()
        showCommandFeedback(CommandFeedback.visibleContainers(count))
    }

    func setNewWindowJoin(_ join: NewWindowJoin) {
        settings.niri.newWindowJoin = join
        niriEngine?.newWindowJoin = join
        showCommandFeedback(CommandFeedback.newWindowJoin(join))
    }

    func cycleNewWindowJoin() {
        let modes = NewWindowJoin.allCases
        let index = modes.firstIndex(of: settings.niri.newWindowJoin) ?? 0
        setNewWindowJoin(modes[(index + 1) % modes.count])
    }

    func setNewWindowPlacement(_ placement: NewWindowPlacement) {
        settings.niri.newWindowPlacement = placement
        niriEngine?.newWindowPlacement = placement
        showCommandFeedback(CommandFeedback.newWindowPlacement(placement))
    }

    func cycleNewWindowPlacement() {
        let placements = NewWindowPlacement.allCases
        let index = placements.firstIndex(of: settings.niri.newWindowPlacement) ?? 0
        setNewWindowPlacement(placements[(index + 1) % placements.count])
    }

    func setPaddingPreset(at index: Int) {
        let presets = settings.gaps.paddingPresets
        guard presets.indices.contains(index) else { return }
        let preset = presets[index]
        setOuterGaps(left: preset.left, right: preset.right, top: preset.top, bottom: preset.bottom)
        showCommandFeedback(CommandFeedback.paddingPreset(preset.name))
    }

    func cyclePaddingPreset() {
        let count = settings.gaps.paddingPresets.count
        guard count > 0 else { return }
        setPaddingPreset(at: ((settings.gaps.activePaddingPresetIndex ?? -1) + 1) % count)
    }

    func setOuterGaps(left: Double, right: Double, top: Double, bottom: Double) {
        settings.gaps.outerGapLeft = left
        settings.gaps.outerGapRight = right
        settings.gaps.outerGapTop = top
        settings.gaps.outerGapBottom = bottom
        updateMonitorGapSettings()
    }

    func enableDwindleLayout() {
        dwindleLayoutHandler.enableDwindleLayout()
    }

    func updateDwindleConfig(
        smartSplit: Bool? = nil,
        defaultSplitRatio: CGFloat? = nil,
        splitWidthMultiplier: CGFloat? = nil,
        singleWindowFit: SingleWindowFit? = nil,
        innerGap: CGFloat? = nil
    ) {
        dwindleLayoutHandler.updateDwindleConfig(
            smartSplit: smartSplit,
            defaultSplitRatio: defaultSplitRatio,
            splitWidthMultiplier: splitWidthMultiplier,
            singleWindowFit: singleWindowFit,
            innerGap: innerGap
        )
    }

    var niriEngine: NiriLayoutEngine? {
        get { workspaceManager.niriEngine }
        set { workspaceManager.niriEngine = newValue }
    }

    var dwindleEngine: DwindleLayoutEngine? {
        get { workspaceManager.dwindleEngine }
        set {
            if let current = workspaceManager.dwindleEngine, current !== newValue {
                layoutRefreshController.stopAllDwindleAnimations()
            }
            workspaceManager.dwindleEngine = newValue
        }
    }
}
