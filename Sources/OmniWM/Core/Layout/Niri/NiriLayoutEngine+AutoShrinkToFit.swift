// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics

extension NiriLayoutEngine {
    @discardableResult
    func autoFitVisibleColumns(context: NiriInteractionContext, state: inout ViewportState) -> Bool {
        assertSanctionedMutation()
        guard interactiveResize == nil,
              !state.preservesGestureOffset,
              state.offsetTransition.kind != .deceleration
        else { return false }
        let projected = projectedColumns(in: context.workspaceId).filter { !$0.windows.isEmpty }
        let visibleCount = effectiveVisibleContainerCount(in: context.workspaceId)
        let signature = autoFitSignature(projected, visibleCount: visibleCount, context: context)
        let workspace = ensureState(for: context.workspaceId)
        let sizesChanged = workspace.autoFitSignature != signature
        workspace.autoFitSignature = signature
        guard let focusIndex = focusedProjectedIndex(projected, context: context, state: state) else { return false }
        let window = autoFitWindow(
            projected,
            focusIndex: focusIndex,
            visibleCount: visibleCount,
            context: context,
            state: state
        )
        let isFullSpan = { (column: NiriContainer) in
            context.orientation == .horizontal ? column.isFullWidth : column.isFullHeight
        }
        guard !window.isEmpty, !window.contains(where: { isFullSpan($0.column) }) else { return false }
        let wantsFullCount = window.count == min(visibleCount, projected.count)
        guard autoFitNeeded(window, wantsFullCount: wantsFullCount, context: context) else {
            guard wantsFullCount,
                  window.count > 1,
                  autoFitFills(window, context: context),
                  effectiveSettings(in: context.workspaceId).centerFocusedColumn != .always
            else { return false }
            alignAutoFitViewport(toFirstOf: window, context: context, state: &state)
            return true
        }
        guard sizesChanged else { return false }
        let focused = projected[focusIndex].column
        if window.count > 1 {
            shrinkVisibleColumnsToFit(around: focused, onScreen: window, context: context, state: &state)
        } else {
            alignAutoFitViewport(toFirstOf: window, context: context, state: &state)
        }
        switch context.orientation {
        case .horizontal: workspace.manualWidthColumnCount = projected.count
        case .vertical: workspace.manualHeightColumnCount = projected.count
        }
        return true
    }

    private func autoFitSignature(
        _ projected: [NiriProjectedColumn],
        visibleCount: Int,
        context: NiriInteractionContext
    ) -> NiriAutoFitSignature {
        NiriAutoFitSignature(
            columnIds: projected.map(\.column.id),
            minimums: projected.map {
                constrainedProjectedPrimarySpan(
                    0, for: $0, workingFrame: context.workingFrame, gap: context.gaps, orientation: context.orientation
                )
            },
            visibleCount: visibleCount,
            workingFrame: context.workingFrame,
            gaps: context.gaps
        )
    }

    private func focusedProjectedIndex(
        _ projected: [NiriProjectedColumn],
        context: NiriInteractionContext,
        state: ViewportState
    ) -> Int? {
        var copy = state
        var focused: NiriContainer?
        _ = withProjectedViewport(state: &copy, context: context) { columns, projectedState in
            if columns.indices.contains(projectedState.activeColumnIndex) {
                focused = columns[projectedState.activeColumnIndex]
            }
        }
        guard let focused else { return nil }
        return projected.firstIndex { $0.column === focused }
    }

    private func autoFitWindow(
        _ projected: [NiriProjectedColumn],
        focusIndex: Int,
        visibleCount: Int,
        context: NiriInteractionContext,
        state: ViewportState
    ) -> [NiriProjectedColumn] {
        let onScreen = onScreenProjectedColumns(in: context.workspaceId, state: state, geometry: context.sizingGeometry)
        let viewStart = onScreen.first.flatMap { first in projected.firstIndex { $0.column === first.column } }
            ?? focusIndex
        let span = context.orientation == .horizontal ? context.workingFrame.width : context.workingFrame.height
        let tolerance = 1 / displayScale(in: context.workspaceId)
        for size in stride(from: min(visibleCount, projected.count), through: 1, by: -1) {
            let start = min(max(viewStart, focusIndex - size + 1), focusIndex, projected.count - size)
            let window = Array(projected[start ..< start + size])
            let minimums = window.reduce(CGFloat(0)) { total, column in
                total + constrainedProjectedPrimarySpan(
                    0,
                    for: column,
                    workingFrame: context.workingFrame,
                    gap: context.gaps,
                    orientation: context.orientation
                )
            }
            if minimums + CGFloat(size + 1) * context.gaps <= span + tolerance {
                return window
            }
        }
        return []
    }

    private func autoFitNeeded(
        _ window: [NiriProjectedColumn],
        wantsFullCount: Bool,
        context: NiriInteractionContext
    ) -> Bool {
        let keyPath = context.orientation.settledSpanKeyPath
        let span = context.orientation == .horizontal ? context.workingFrame.width : context.workingFrame.height
        let used = window.reduce(CGFloat(0)) { $0 + $1.column[keyPath: keyPath] }
            + CGFloat(window.count + 1) * context.gaps
        let tolerance = 1 / displayScale(in: context.workspaceId)
        return wantsFullCount ? used > span + tolerance : abs(used - span) > tolerance
    }

    private func autoFitFills(_ window: [NiriProjectedColumn], context: NiriInteractionContext) -> Bool {
        let keyPath = context.orientation.settledSpanKeyPath
        let span = context.orientation == .horizontal ? context.workingFrame.width : context.workingFrame.height
        let used = window.reduce(CGFloat(0)) { $0 + $1.column[keyPath: keyPath] }
            + CGFloat(window.count + 1) * context.gaps
        return abs(used - span) <= 1 / displayScale(in: context.workspaceId)
    }

    private func alignAutoFitViewport(
        toFirstOf window: [NiriProjectedColumn],
        context: NiriInteractionContext,
        state: inout ViewportState
    ) {
        let scale = displayScale(in: context.workspaceId)
        _ = withProjectedViewport(state: &state, context: context) { columns, projectedState in
            guard let firstIndex = columns.firstIndex(where: { $0 === window.first?.column }) else { return }
            let keyPath = context.orientation.settledSpanKeyPath
            let firstPosition = projectedState.containerPosition(
                at: firstIndex, containers: columns, gap: context.gaps, sizeKeyPath: keyPath
            )
            let activePosition = projectedState.containerPosition(
                at: projectedState.activeColumnIndex, containers: columns, gap: context.gaps, sizeKeyPath: keyPath
            )
            projectedState.animateToOffset(
                firstPosition - context.gaps - activePosition,
                motion: context.motion,
                scale: scale
            )
        }
    }
}

struct NiriAutoFitSignature: Equatable {
    let columnIds: [NodeId]
    let minimums: [CGFloat]
    let visibleCount: Int
    let workingFrame: CGRect
    let gaps: CGFloat
}
