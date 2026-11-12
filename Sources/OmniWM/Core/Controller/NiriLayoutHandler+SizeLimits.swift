// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics

extension NiriLayoutHandler {
    func noteRefusedMinimum(for token: WindowToken) {
        guard lastPrimaryResizeTokens.contains(token),
              let minimum = controller?.workspaceManager.observedSizeEvidence(for: token)?.minSize
        else { return }
        refusedPrimaryMinimums[token] = minimum
    }

    func trustsRefusedMinimum(
        of token: WindowToken,
        evidence: ObservedSizeEvidence,
        horizontal: Bool,
        shrinking: Bool
    ) -> Bool {
        guard let refused = refusedPrimaryMinimums.removeValue(forKey: token) else { return false }
        guard shrinking,
              horizontal ? refused.width == evidence.minSize.width : refused.height == evidence.minSize.height
        else { return false }
        refusedPrimaryMinimums[token] = refused
        controller?.showSizeLimitFeedback(for: token, minimum: true, width: horizontal ? refused.width : refused.height)
        return true
    }

    func noteMaximumIfPinned(
        _ window: NiriWindow,
        in column: NiriContainer,
        change: NiriSizeChange,
        context: NiriInteractionContext
    ) {
        guard change.grows, let controller else { return }
        let horizontal = context.orientation == .horizontal
        let maximum = horizontal ? window.constraints.maxSize.width : window.constraints.maxSize.height
        let current = horizontal ? column.cachedWidth : column.cachedHeight
        guard maximum > 1, current >= maximum - 0.5 else { return }
        controller.showSizeLimitFeedback(for: window.token, minimum: false, width: maximum)
    }
}

extension NiriSizeChange {
    var grows: Bool {
        switch self {
        case let .adjustFixed(delta),
             let .adjustProportion(delta):
            delta > 0
        case .setFixed,
             .setProportion:
            false
        }
    }

    var shrinks: Bool {
        switch self {
        case let .adjustFixed(delta),
             let .adjustProportion(delta):
            delta < 0
        case .setFixed,
             .setProportion:
            false
        }
    }
}
