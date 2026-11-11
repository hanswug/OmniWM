// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import QuartzCore
import XCTest

@MainActor
final class NiriResetRetestsMinimumsTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)
    private let sidePadding: CGFloat = 200
    private let innerGap: CGFloat = 10

    func testResetRetestsAStaleLearnedMinimum() throws {
        let fixture = try makeFixture(windowCount: 3, visibleContainerCount: 3)
        try learnMinimumWidth(1000, for: fixture.tokens[0], fixture: fixture)
        XCTAssertGreaterThanOrEqual(try settledFrames(fixture).map(\.width).max() ?? 0, 1000)

        fixture.controller.niriLayoutHandler.resetLayout()

        let frames = try settledFrames(fixture)
        let third = (monitorFrame.width - 2 * sidePadding - 2 * innerGap) / 3
        for frame in frames {
            XCTAssertEqual(frame.width, third, accuracy: 1)
        }
        XCTAssertEqual(frames.first?.minX ?? 0, sidePadding, accuracy: 1)
        XCTAssertEqual(frames.last?.maxX ?? 0, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testVisibleContainerResetRetestsAStaleLearnedMinimum() throws {
        let fixture = try makeFixture(windowCount: 3, visibleContainerCount: 2)
        fixture.controller.settings.niri.visibleContainerChangeAction = .reset
        try learnMinimumWidth(1000, for: fixture.tokens[0], fixture: fixture)

        fixture.controller.settings.niri.visibleContainerCount = 3
        fixture.controller.updateNiriConfig(visibleContainerCount: 3)
        fixture.controller.rebalanceNiriSizesForVisibleContainerCountChange()

        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames.first?.minX ?? 0, sidePadding, accuracy: 1)
        XCTAssertEqual(frames.last?.maxX ?? 0, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testBalanceKeepsALearnedMinimum() throws {
        let fixture = try makeFixture(windowCount: 3, visibleContainerCount: 3)
        try learnMinimumWidth(1000, for: fixture.tokens[0], fixture: fixture)

        fixture.controller.niriLayoutHandler.balanceSizes()

        XCTAssertNotNil(fixture.controller.workspaceManager.observedSizeEvidence(for: fixture.tokens[0]))
    }

    func testShrinkToFitGrowsRightAwayAfterRefusedShrinks() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 2)
        fixture.controller.settings.niri.shrinkToFit = true
        try learnMinimumWidth(1000, for: fixture.tokens[0], fixture: fixture)
        for _ in 0 ..< 3 {
            XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
                .adjustProportion(-10),
                target: .window(fixture.handles[0])
            ))
            try learnMinimumWidth(1000, for: fixture.tokens[0], fixture: fixture)
        }
        XCTAssertEqual(try settledFrames(fixture)[0].width, 1000, accuracy: 1)

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .adjustProportion(10),
            target: .window(fixture.handles[0])
        ))

        let frames = try settledFrames(fixture)
        XCTAssertGreaterThan(frames[0].width, 1000 + 100)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
    }

    private func learnMinimumWidth(_ width: CGFloat, for token: WindowToken, fixture: Fixture) throws {
        var evidence = ObservedSizeEvidence()
        evidence.minSize = CGSize(width: width, height: 1)
        XCTAssertTrue(fixture.controller.workspaceManager.setObservedSizeEvidence(evidence, for: token))
        _ = try layoutFrames(fixture)
    }

    private struct Fixture {
        let controller: WMController
        let workspaceId: WorkspaceDescriptor.ID
        let tokens: [WindowToken]
        let handles: [WindowHandle]
    }

    private func makeFixture(windowCount: Int, visibleContainerCount: Int) throws -> Fixture {
        let settings = makeSettingsStore()
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = Double(innerGap)
        settings.gaps.outerGapLeft = Double(sidePadding)
        settings.gaps.outerGapRight = Double(sidePadding)
        settings.gaps.outerGapTop = 0
        settings.gaps.outerGapBottom = 0
        settings.niri.edgeGaps = false
        let monitor = Monitor(
            id: .init(displayId: 1),
            displayId: 1,
            frame: monitorFrame,
            visibleFrame: monitorFrame,
            hasNotch: false,
            name: "Main"
        )
        settings.workspaces.configurations = [
            WorkspaceConfiguration(
                name: "1",
                monitorAssignment: .specificDisplay(OutputId(from: monitor)),
                layoutType: .niri
            )
        ]
        let controller = WMController(settings: settings)
        controller.setGapSize(innerGap, publishChange: false)
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.workspaceManager.applySettings()
        controller.niriLayoutHandler.enableNiriLayout()
        controller.syncMonitorsToNiriEngine()
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        let tokens = (0 ..< windowCount).map { index in
            controller.workspaceManager.addWindow(
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(870 + index)), windowId: 870 + index),
                pid: pid_t(870 + index),
                windowId: 870 + index,
                to: workspaceId
            )
        }
        let fixture = try Fixture(
            controller: controller,
            workspaceId: workspaceId,
            tokens: tokens,
            handles: tokens.map { try XCTUnwrap(controller.workspaceManager.handle(for: $0)) }
        )
        _ = try layoutFrames(fixture)
        controller.settings.niri.visibleContainerCount = visibleContainerCount
        controller.settings.niri.defaultContainerPrimarySpan = nil
        controller.updateNiriConfig(
            visibleContainerCount: visibleContainerCount,
            defaultContainerPrimarySpan: .some(nil)
        )
        let engine = try XCTUnwrap(controller.niriEngine)
        let first = try XCTUnwrap(engine.findNode(for: tokens[0], in: workspaceId))
        _ = controller.workspaceManager.commitWorkspaceSelection(
            nodeId: first.id,
            focusedToken: tokens[0],
            in: workspaceId,
            onMonitor: monitor.id
        )
        controller.workspaceManager.withNiriViewportState(for: workspaceId) { state in
            state.activeColumnIndex = 0
            state.viewOffset = -innerGap
            state.clearOffsetTransition()
        }
        _ = try layoutFrames(fixture)
        return fixture
    }

    private func settledFrames(_ fixture: Fixture) throws -> [CGRect] {
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        _ = engine.tickAllColumnAnimations(in: fixture.workspaceId, at: CACurrentMediaTime() + 5)
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            state.clearOffsetTransition()
        }
        _ = try layoutFrames(fixture)
        _ = engine.tickAllColumnAnimations(in: fixture.workspaceId, at: CACurrentMediaTime() + 10)
        return try layoutFrames(fixture).sorted { $0.minX < $1.minX }
    }

    private func layoutFrames(_ fixture: Fixture) throws -> [CGRect] {
        let plans = fixture.controller.workspaceManager.withBatchedLayoutBuild {
            fixture.controller.niriLayoutHandler.layoutWithNiriEngine(activeWorkspaces: [fixture.workspaceId])
        }
        let plan = try XCTUnwrap(plans.first { $0.workspaceId == fixture.workspaceId })
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        return try fixture.tokens.map { token in
            if let frame = plan.diff.frameChanges.first(where: { $0.token == token })?.frame {
                return frame
            }
            return try XCTUnwrap(engine.findNode(for: token, in: fixture.workspaceId)?.renderedFrame)
        }
    }

    private func makeSettingsStore() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMNiriResetRetestsMinimumsTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return SettingsStore(
            persistence: SettingsFilePersistence(
                directory: root.appendingPathComponent("config", isDirectory: true),
                startWatching: false,
                deferSaves: false
            ),
            runtimeState: RuntimeStateStore(
                directory: root.appendingPathComponent("state", isDirectory: true),
                deferSaves: false
            ),
            autosaveEnabled: false
        )
    }
}
