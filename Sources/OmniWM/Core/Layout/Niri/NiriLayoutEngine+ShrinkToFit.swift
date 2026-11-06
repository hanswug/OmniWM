// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics

extension NiriLayoutEngine {
    func onScreenColumns(
        in workspaceId: WorkspaceDescriptor.ID,
        state: ViewportState,
        geometry: NiriSizingGeometry
    ) -> [NiriContainer] {
        let projected = projectedColumns(in: workspaceId)
        guard let relations = columnSummary(in: workspaceId, state: state, geometry: geometry).viewport,
              relations.count == projected.count
        else { return [] }
        return zip(projected, relations).compactMap { column, relation in
            relation == .intersecting && !column.windows.isEmpty ? column.column : nil
        }
    }

    func shrinkOnScreenColumnsToFit(
        around resized: NiriContainer,
        onScreen: [NiriContainer],
        context: NiriInteractionContext,
        state: inout ViewportState
    ) {
        assertSanctionedMutation()
        guard onScreen.count > 1, onScreen.contains(where: { $0 === resized }) else { return }
        let horizontal = context.orientation == .horizontal
        let workingSpan = horizontal ? context.workingFrame.width : context.workingFrame.height
        let available = workingSpan - CGFloat(onScreen.count + 1) * context.gaps
        guard available > 0 else { return }

        let others = onScreen.filter { $0 !== resized }
        let otherMinimums = others.map { primaryMinimum(of: $0, horizontal: horizontal, in: context.workspaceId) }
        let resizedMinimum = primaryMinimum(of: resized, horizontal: horizontal, in: context.workspaceId)
        let requested = horizontal ? resized.settledWidth : resized.settledHeight
        let resizedSpan = max(resizedMinimum, min(requested, available - otherMinimums.reduce(0, +)))
            .rounded(.down)
        let shares = Self.shrinkToFitShares(
            remaining: available - resizedSpan,
            weights: others.map { horizontal ? $0.settledWidth : $0.settledHeight },
            minimums: otherMinimums
        )

        applyFittedPrimarySpan(resizedSpan, to: resized, context: context)
        for (column, share) in zip(others, shares) {
            applyFittedPrimarySpan(share, to: column, context: context)
        }
        alignViewport(toFirstOf: onScreen, context: context, state: &state)
    }

    static func shrinkToFitShares(remaining: CGFloat, weights: [CGFloat], minimums: [CGFloat]) -> [CGFloat] {
        var shares = minimums
        var free = Array(weights.indices)
        var budget = remaining
        while !free.isEmpty {
            let total = free.reduce(CGFloat(0)) { $0 + max(weights[$1], 1) }
            let pinned = free.filter { budget * max(weights[$0], 1) / total < minimums[$0] }
            guard !pinned.isEmpty else { break }
            budget -= pinned.reduce(CGFloat(0)) { $0 + minimums[$1] }
            free.removeAll { pinned.contains($0) }
        }
        guard let last = free.last else { return shares }
        let total = free.reduce(CGFloat(0)) { $0 + max(weights[$1], 1) }
        var assigned: CGFloat = 0
        for index in free.dropLast() {
            shares[index] = (budget * max(weights[index], 1) / total).rounded(.down)
            assigned += shares[index]
        }
        shares[last] = budget - assigned
        return shares
    }

    private func primaryMinimum(
        of column: NiriContainer,
        horizontal: Bool,
        in workspaceId: WorkspaceDescriptor.ID
    ) -> CGFloat {
        horizontal
            ? projectedWidthBounds(for: column, workspaceId: workspaceId).min
            : projectedHeightBounds(for: column, workspaceId: workspaceId).min
    }

    private func applyFittedPrimarySpan(
        _ span: CGFloat,
        to column: NiriContainer,
        context: NiriInteractionContext
    ) {
        cancelInteractiveResize(for: column, in: context.workspaceId)
        let config = context.motion.scaled(windowMovementAnimationConfig)
        let refreshRate = displayRefreshRate(in: context.workspaceId)
        switch context.orientation {
        case .horizontal:
            column.width = .fixed(span)
            column.presetWidthIdx = nil
            column.isFullWidth = false
            column.savedWidth = nil
            column.fittedWidth = nil
            column.animateWidthTo(
                newWidth: span,
                clock: animationClock,
                config: config,
                displayRefreshRate: refreshRate,
                animated: context.motion.animationsEnabled
            )
        case .vertical:
            column.height = .fixed(span)
            column.isFullHeight = false
            column.savedHeight = nil
            column.fittedHeight = nil
            column.animateHeightTo(
                newHeight: span,
                clock: animationClock,
                config: config,
                displayRefreshRate: refreshRate,
                animated: context.motion.animationsEnabled
            )
        }
    }

    private func alignViewport(
        toFirstOf onScreen: [NiriContainer],
        context: NiriInteractionContext,
        state: inout ViewportState
    ) {
        let projected = projectedColumns(in: context.workspaceId)
        let activeIndex = projectedActiveColumnIndex(state: state, columns: projected, in: context.workspaceId)
        guard let firstIndex = projected.firstIndex(where: { $0.column === onScreen.first }),
              firstIndex <= activeIndex
        else { return }
        let horizontal = context.orientation == .horizontal
        let leading = projected[firstIndex ..< activeIndex].reduce(CGFloat(0)) { total, column in
            total + (horizontal ? column.column.settledWidth : column.column.settledHeight) + context.gaps
        }
        state.springOffset(to: -leading - context.gaps)
    }
}
