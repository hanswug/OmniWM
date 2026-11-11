// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Foundation
import QuartzCore

extension NiriLayoutHandler {
    func toggleFullscreen() {
        performWindowSizing(on: .focused, focusesWindowAfterLayout: true) { engine, windowNode, context, state in
            engine.toggleFullscreen(windowNode, motion: context.motion, state: &state)
            if windowNode.sizingMode == .normal {
                engine.recoverSettledCoverage(context: context, state: &state)
            }
            return .fullscreenToggled(token: windowNode.token)
        }
    }

    func cycleSize(forward: Bool) {
        cycleContainerPrimarySpan(forward: forward)
    }

    @discardableResult
    func cycleContainerPrimarySpan(forward: Bool, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, state in
            guard let column = engine.findColumn(containing: windowNode, in: context.workspaceId) else { return nil }
            retestObservedPrimaryMinimums(in: column, engine: engine, context: context, forShrinkToFit: true)
            fittingVisibleColumns(around: column, engine: engine, context: context, state: &state) { state in
                engine.toggleContainerPrimarySpan(column, forwards: forward, context: context, state: &state)
            }
            return .containerPrimarySpanChanged
        }
    }

    @discardableResult
    func cycleWindowPrimarySpan(forward: Bool, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, state in
            let column = engine.findColumn(containing: windowNode, in: context.workspaceId)
            if let column {
                retestObservedPrimaryMinimums(in: column, engine: engine, context: context, forShrinkToFit: true)
            }
            fittingVisibleColumns(around: column, engine: engine, context: context, state: &state) { state in
                engine.toggleWindowPrimarySpan(windowNode, forwards: forward, context: context, state: &state)
            }
            return .windowSizeChanged(token: windowNode.token)
        }
    }

    static let shrinkToFitRetestWindow: CFTimeInterval = 2

    func refitAfterRetestedMinimumGrew(for token: WindowToken, now: CFTimeInterval = CACurrentMediaTime()) {
        let anchorId = shrinkToFitRefitAnchors.removeValue(forKey: token)
        guard let retestedAt = shrinkToFitRetests.removeValue(forKey: token),
              now - retestedAt <= Self.shrinkToFitRetestWindow,
              let controller,
              controller.settings.niri.shrinkToFit,
              let handle = controller.workspaceManager.handle(for: token),
              let observedMinimum = controller.workspaceManager.observedSizeEvidence(for: token)?.minSize
        else { return }
        performWindowSizing(on: .window(handle)) { engine, windowNode, context, state in
            guard engine.interactiveResize == nil,
                  let column = engine.findColumn(containing: windowNode, in: context.workspaceId)
            else { return nil }
            let onScreen = engine.onScreenProjectedColumns(
                in: context.workspaceId,
                state: state,
                geometry: context.sizingGeometry
            )
            guard onScreen.count > 1 else { return nil }
            var constraints = windowNode.constraints
            constraints.minSize.width = max(constraints.minSize.width, observedMinimum.width)
            constraints.minSize.height = max(constraints.minSize.height, observedMinimum.height)
            engine.updateWindowConstraints(
                for: token,
                constraints: constraints,
                packingHints: windowNode.packingHints,
                in: context.workspaceId,
                motion: context.motion
            )
            let anchor = anchorId.flatMap { id in onScreen.first { $0.column.id == id }?.column } ?? column
            engine.shrinkVisibleColumnsToFit(around: anchor, onScreen: onScreen, context: context, state: &state)
            return .containerPrimarySpanChanged
        }
    }

    private func fittingVisibleColumns(
        around column: NiriContainer?,
        engine: NiriLayoutEngine,
        context: NiriInteractionContext,
        state: inout ViewportState,
        _ resize: (inout ViewportState) -> Void
    ) {
        let onScreen = controller?.settings.niri.shrinkToFit == true
            ? engine.onScreenProjectedColumns(in: context.workspaceId, state: state, geometry: context.sizingGeometry)
            : []
        resize(&state)
        guard let column, !onScreen.isEmpty else { return }
        engine.shrinkVisibleColumnsToFit(around: column, onScreen: onScreen, context: context, state: &state)
        let now = CACurrentMediaTime()
        for neighbour in onScreen where neighbour.column !== column {
            for window in neighbour.column.windowNodes {
                shrinkToFitRetests[window.token] = now
                shrinkToFitRefitAnchors[window.token] = column.id
            }
        }
    }

    @discardableResult
    func cycleWindowSecondarySpan(forward: Bool, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, _ in
            engine.toggleWindowSecondarySpan(
                windowNode,
                forwards: forward,
                in: context.workspaceId,
                geometry: NiriSizingGeometry(
                    workingFrame: context.workingFrame,
                    gaps: context.gaps,
                    orientation: context.orientation
                )
            )
            return .windowSizeChanged(token: windowNode.token)
        }
    }

    @discardableResult
    func toggleContainerFullPrimarySpan(target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, state in
            guard let column = engine.findColumn(containing: windowNode, in: context.workspaceId) else { return nil }
            engine.toggleContainerFullPrimarySpan(column, context: context, state: &state)
            return .containerPrimarySpanChanged
        }
    }

    func expandContainerToAvailablePrimarySpan() {
        performWindowSizing(on: .focused) { engine, windowNode, context, state in
            guard let column = engine.findColumn(containing: windowNode, in: context.workspaceId) else { return nil }
            engine.expandContainerToAvailablePrimarySpan(column, context: context, state: &state)
            return .containerPrimarySpanChanged
        }
    }

    @discardableResult
    func resetWindowSecondarySpan(target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, _ in
            engine.resetWindowSecondarySpan(windowNode, in: context.workspaceId, orientation: context.orientation)
            return .windowSizeChanged(token: windowNode.token)
        }
    }

    func centerColumn() {
        withNiriWorkspaceContext { engine, wsId, motion, state, _, workingFrame, gaps, orientation in
            guard engine.centerColumn(
                context: .init(
                    workspaceId: wsId,
                    motion: motion,
                    workingFrame: workingFrame,
                    gaps: gaps,
                    orientation: orientation
                ),
                state: &state
            ) else { return }

            requestLayoutCommandRelayout(in: wsId)
            startScrollAnimationIfNeeded(for: wsId, state: state, engine: engine)
        }
    }

    func centerVisibleColumns() {
        withNiriWorkspaceContext { engine, wsId, motion, state, _, workingFrame, gaps, orientation in
            guard engine.centerVisibleColumns(
                context: .init(
                    workspaceId: wsId,
                    motion: motion,
                    workingFrame: workingFrame,
                    gaps: gaps,
                    orientation: orientation
                ),
                state: &state
            ) else { return }

            requestLayoutCommandRelayout(in: wsId)
            startScrollAnimationIfNeeded(for: wsId, state: state, engine: engine)
        }
    }

    @discardableResult
    func setContainerPrimarySpan(_ change: NiriSizeChange, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, state in
            guard let column = engine.findColumn(containing: windowNode, in: context.workspaceId) else { return nil }
            retestObservedPrimaryMinimums(in: column, engine: engine, context: context, forShrinkToFit: true)
            fittingVisibleColumns(around: column, engine: engine, context: context, state: &state) { state in
                engine.setContainerPrimarySpan(column, change: change, context: context, state: &state)
            }
            return .containerPrimarySpanChanged
        }
    }

    @discardableResult
    func setWindowPrimarySpan(_ change: NiriSizeChange, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, state in
            let column = engine.findColumn(containing: windowNode, in: context.workspaceId)
            if let column {
                retestObservedPrimaryMinimums(in: column, engine: engine, context: context, forShrinkToFit: true)
            }
            fittingVisibleColumns(around: column, engine: engine, context: context, state: &state) { state in
                engine.setWindowPrimarySpan(windowNode, change: change, context: context, state: &state)
            }
            return .windowSizeChanged(token: windowNode.token)
        }
    }

    private func retestObservedPrimaryMinimums(
        in workspaceId: WorkspaceDescriptor.ID,
        engine: NiriLayoutEngine,
        context: NiriInteractionContext
    ) {
        for column in engine.columns(in: workspaceId) {
            retestObservedPrimaryMinimums(in: column, engine: engine, context: context)
        }
    }

    private func retestObservedPrimaryMinimums(
        in column: NiriContainer,
        engine: NiriLayoutEngine,
        context: NiriInteractionContext,
        forShrinkToFit: Bool = false
    ) {
        guard let controller else { return }
        if forShrinkToFit {
            shrinkToFitRetests.removeAll()
            shrinkToFitRefitAnchors.removeAll()
        }
        let horizontal = context.orientation == .horizontal
        for window in column.windowNodes {
            let token = window.token
            guard var evidence = controller.workspaceManager.observedSizeEvidence(for: token),
                  (horizontal ? evidence.minSize.width : evidence.minSize.height) > 1
            else { continue }
            if horizontal {
                evidence.minSize.width = 1
            } else {
                evidence.minSize.height = 1
            }
            _ = controller.workspaceManager.setObservedSizeEvidence(evidence, for: token)
            if forShrinkToFit, controller.settings.niri.shrinkToFit {
                shrinkToFitRetests[token] = CACurrentMediaTime()
            }
            let declared = controller.workspaceManager.cachedConstraints(
                for: token,
                maxAge: .greatestFiniteMagnitude
            )?.minSize
            let ruleEffects = controller.workspaceManager.entry(for: token)?.ruleEffects
            var constraints = window.constraints
            if horizontal {
                let floor = max(declared?.width ?? 1, ruleEffects?.minWidth ?? 1)
                constraints.minSize.width = min(constraints.minSize.width, floor)
            } else {
                let floor = max(declared?.height ?? 1, ruleEffects?.minHeight ?? 1)
                constraints.minSize.height = min(constraints.minSize.height, floor)
            }
            engine.updateWindowConstraints(
                for: token,
                constraints: constraints,
                packingHints: window.packingHints,
                in: context.workspaceId,
                motion: context.motion
            )
        }
    }

    @discardableResult
    func setWindowSecondarySpan(_ change: NiriSizeChange, target: WindowTarget = .focused) -> Bool {
        performWindowSizing(on: target) { engine, windowNode, context, _ in
            engine.setWindowSecondarySpan(
                windowNode,
                change: change,
                in: context.workspaceId,
                geometry: NiriSizingGeometry(
                    workingFrame: context.workingFrame,
                    gaps: context.gaps,
                    orientation: context.orientation
                )
            )
            return .windowSizeChanged(token: windowNode.token)
        }
    }

    func balanceSizes() {
        balanceSizes(fillsUnusedSpace: false)
    }

    func resetLayout() {
        balanceSizes(fillsUnusedSpace: true)
    }

    private func balanceSizes(fillsUnusedSpace: Bool) {
        withNiriWorkspaceContext { engine, wsId, motion, state, _, workingFrame, gaps, orientation in
            if fillsUnusedSpace {
                retestObservedPrimaryMinimums(
                    in: wsId,
                    engine: engine,
                    context: .init(
                        workspaceId: wsId, motion: motion, workingFrame: workingFrame, gaps: gaps,
                        orientation: orientation
                    )
                )
            }
            guard engine.balanceSizes(
                in: wsId,
                motion: motion,
                workingFrame: workingFrame,
                gaps: gaps,
                orientation: orientation,
                fillsUnusedSpace: fillsUnusedSpace
            ) else { return }
            engine.recoverSettledCoverage(
                context: .init(
                    workspaceId: wsId,
                    motion: motion,
                    workingFrame: workingFrame,
                    gaps: gaps,
                    orientation: orientation
                ),
                state: &state
            )
            recordLayoutOperation(.sizesBalanced, in: wsId)
            requestLayoutCommandRelayout(in: wsId)
            startScrollAnimationIfNeeded(for: wsId, state: state, engine: engine)
        }
    }

    func balanceSizesAllWorkspaces(
        on monitorId: Monitor.ID? = nil,
        onlyAutomaticSpans: Bool = false,
        fillsUnusedSpace: Bool = false
    ) {
        guard let controller, let engine = controller.niriEngine else { return }
        var changed: Set<WorkspaceDescriptor.ID> = []
        for descriptor in controller.workspaceManager.workspaces {
            guard controller.settings.workspaces.layoutType(for: descriptor.name) != .dwindle else { continue }
            if let monitorId, controller.workspaceManager.monitorId(for: descriptor.id) != monitorId { continue }
            if onlyAutomaticSpans,
               engine.effectiveSettings(in: descriptor.id).defaultContainerPrimarySpan != nil { continue }
            withNiriWorkspaceContext(for: descriptor.id) {
                engine, wsId, motion, state, _, workingFrame, gaps, orientation in
                if fillsUnusedSpace {
                    retestObservedPrimaryMinimums(
                        in: wsId,
                        engine: engine,
                        context: .init(
                            workspaceId: wsId, motion: motion, workingFrame: workingFrame, gaps: gaps,
                            orientation: orientation
                        )
                    )
                }
                guard engine.balanceSizes(
                    in: wsId,
                    motion: motion,
                    workingFrame: workingFrame,
                    gaps: gaps,
                    orientation: orientation,
                    fillsUnusedSpace: fillsUnusedSpace
                ) else { return }
                engine.recoverSettledCoverage(
                    context: .init(
                        workspaceId: wsId,
                        motion: motion,
                        workingFrame: workingFrame,
                        gaps: gaps,
                        orientation: orientation
                    ),
                    state: &state
                )
                changed.insert(wsId)
                recordLayoutOperation(.sizesBalanced, in: wsId)
                startScrollAnimationIfNeeded(for: wsId, state: state, engine: engine)
            }
        }
        if !changed.isEmpty {
            controller.layoutRefreshController.requestLayoutCommandRelayout(affectedWorkspaceIds: changed)
        }
    }

    @discardableResult
    private func performWindowSizing(
        on target: WindowTarget,
        focusesWindowAfterLayout: Bool = false,
        _ operation: (NiriLayoutEngine, NiriWindow, NiriInteractionContext, inout ViewportState) -> LayoutOperation?
    ) -> Bool {
        var sized: (workspaceId: WorkspaceDescriptor.ID, token: WindowToken)?
        withNiriWindowContext(target) { engine, windowNode, context, state in
            guard let layoutOperation = operation(engine, windowNode, context, &state) else { return }
            let workspaceId = context.workspaceId
            recordLayoutOperation(layoutOperation, in: workspaceId)
            startScrollAnimationIfNeeded(for: workspaceId, state: state, engine: engine)
            beginResizePreview(in: workspaceId)
            sized = (workspaceId, windowNode.token)
        }
        guard let sized else { return false }
        requestLayoutCommandRelayout(
            in: sized.workspaceId,
            postLayout: focusesWindowAfterLayout
                ? controller?.focusWindowAfterLayout(sized.token, in: sized.workspaceId)
                : nil
        )
        return true
    }

    private func beginResizePreview(in workspaceId: WorkspaceDescriptor.ID) {
        guard let controller, hasScrollAnimation(for: workspaceId) else { return }
        controller.resizeOverlay.begin(
            workspaceId: workspaceId,
            style: controller.settings.gestures.resizePreviewStyle,
            pointerDriven: false
        )
    }
}
