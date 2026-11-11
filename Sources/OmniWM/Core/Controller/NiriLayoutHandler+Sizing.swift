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
            retestObservedPrimaryMinimums(in: column, engine: engine, context: context)
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
                retestObservedPrimaryMinimums(in: column, engine: engine, context: context)
            }
            fittingVisibleColumns(around: column, engine: engine, context: context, state: &state) { state in
                engine.toggleWindowPrimarySpan(windowNode, forwards: forward, context: context, state: &state)
            }
            return .windowSizeChanged(token: windowNode.token)
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
            retestObservedPrimaryMinimums(in: column, engine: engine, context: context)
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
                retestObservedPrimaryMinimums(in: column, engine: engine, context: context)
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
        context: NiriInteractionContext
    ) {
        guard let controller else { return }
        let horizontal = context.orientation == .horizontal
        let shownSpan = shownPrimarySpan(of: column, engine: engine, context: context)
        var retested = false
        defer { if retested { anchorPrimarySpan(of: column, to: shownSpan, context: context) } }
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
            retested = true
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

    private func shownPrimarySpan(
        of column: NiriContainer,
        engine: NiriLayoutEngine,
        context: NiriInteractionContext
    ) -> CGFloat? {
        let horizontal = context.orientation == .horizontal
        guard !(horizontal ? column.isFullWidth : column.isFullHeight) else { return nil }
        return column.resolvedPrimarySpan(
            horizontal ? column.width : column.height,
            orientation: context.orientation,
            availableSpace: horizontal ? context.workingFrame.width : context.workingFrame.height,
            gaps: context.gaps,
            contentInset: horizontal ? engine.tabContentInset(for: column) : 0,
            applyingPackingHints: false
        )
    }

    private func anchorPrimarySpan(of column: NiriContainer, to shownSpan: CGFloat?, context: NiriInteractionContext) {
        guard let shownSpan else { return }
        let horizontal = context.orientation == .horizontal
        let axisSpan = horizontal ? context.workingFrame.width : context.workingFrame.height
        let anchored: ProportionalSize
        switch horizontal ? column.width : column.height {
        case let .proportion(proportion):
            guard (axisSpan - context.gaps) * proportion - context.gaps < shownSpan else { return }
            anchored = .proportion((shownSpan + context.gaps) / (axisSpan - context.gaps))
        case let .fixed(size):
            guard size < shownSpan else { return }
            anchored = .fixed(shownSpan)
        }
        if horizontal {
            column.width = anchored
        } else {
            column.height = anchored
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
            if fillsUnusedSpace {
                engine.autoFitVisibleColumns(
                    context: .init(
                        workspaceId: wsId, motion: motion, workingFrame: workingFrame, gaps: gaps,
                        orientation: orientation
                    ),
                    state: &state
                )
            }
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
