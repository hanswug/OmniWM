// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import XCTest

@MainActor
final class DwindleResetLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1800, height: 1000)

    func testResetGivesEveryTileAnEqualArea() throws {
        let engine = DwindleLayoutEngine()
        engine.settings.innerGap = 0
        let workspaceId = WorkspaceDescriptor.ID()
        let tokens = (1 ... 3).map { WindowToken(pid: pid_t($0), windowId: $0) }
        for token in tokens {
            _ = engine.addWindow(token: token, to: workspaceId, activeWindowFrame: nil)
            _ = engine.calculateLayout(for: workspaceId, screen: screen)
        }

        _ = engine.balanceSizes(in: workspaceId)
        let balancedAreas = areas(engine.calculateLayout(for: workspaceId, screen: screen), tokens)
        XCTAssertGreaterThan((balancedAreas.max() ?? 0) / (balancedAreas.min() ?? 1), 1.5)

        XCTAssertTrue(engine.resetLayout(in: workspaceId))
        let resetAreas = areas(engine.calculateLayout(for: workspaceId, screen: screen), tokens)
        let expected = screen.width * screen.height / 3
        for area in resetAreas {
            XCTAssertEqual(area, expected, accuracy: expected * 0.02)
        }
        XCTAssertFalse(engine.resetLayout(in: workspaceId))
    }

    private func areas(_ frames: [WindowToken: CGRect], _ tokens: [WindowToken]) -> [CGFloat] {
        tokens.compactMap { frames[$0] }.map { $0.width * $0.height }
    }
}
