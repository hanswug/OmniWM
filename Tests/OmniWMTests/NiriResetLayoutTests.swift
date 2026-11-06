// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import QuartzCore
import XCTest

@MainActor
final class NiriResetLayoutTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)
    private let sidePadding: CGFloat = 200
    private let innerGap: CGFloat = 10

    func testResetWithFewerColumnsThanVisibleContainersFillsTheWorkingArea() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 3)
        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(20),
            target: .window(fixture.handles[0])
        ))
        fixture.controller.niriLayoutHandler.resetLayout()

        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames[0].width, frames[1].width, accuracy: 1)
        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
        XCTAssertEqual(frames[1].minX - frames[0].maxX, innerGap, accuracy: 1)
    }

    func testFillStaysAfterResetUntilTheUserResizes() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 3)
        fixture.controller.niriLayoutHandler.resetLayout()
        let balanced = try settledFrames(fixture)
        XCTAssertEqual(balanced[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(20),
            target: .window(fixture.handles[0])
        ))
        let resized = try settledFrames(fixture)
        XCTAssertLessThan(resized[0].width, balanced[0].width - 100)
    }

    func testResetWithAsManyColumnsAsVisibleContainersSplitsEvenly() throws {
        let fixture = try makeFixture(windowCount: 3, visibleContainerCount: 3)
        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(60),
            target: .window(fixture.handles[0])
        ))
        fixture.controller.niriLayoutHandler.resetLayout()

        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let widths = engine.columns(in: fixture.workspaceId).map(\.settledWidth)
        let expected = (monitorFrame.width - 2 * sidePadding - 2 * innerGap) / 3
        for width in widths {
            XCTAssertEqual(width, expected, accuracy: 1)
        }
    }

    func testBalanceStillKeepsTheConfiguredSpansWithFewerColumns() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 3)
        fixture.controller.niriLayoutHandler.balanceSizes()

        let frames = try settledFrames(fixture)
        let third = (monitorFrame.width - 2 * sidePadding - 2 * innerGap) / 3
        XCTAssertEqual(frames[0].width, third, accuracy: 1)
        XCTAssertLessThan(frames[1].maxX, monitorFrame.width - sidePadding - 100)
    }

    func testResetCommandRunsThroughTheCommandHandler() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 3)
        XCTAssertEqual(fixture.controller.commandHandler.performCommand(.sizing(.resetLayout)), .executed)

        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testVisibleContainerCountChangeBalancesByDefault() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 2)
        fixture.controller.settings.niri.visibleContainerCount = 3
        fixture.controller.updateNiriConfig(visibleContainerCount: 3)
        fixture.controller.rebalanceNiriSizesForVisibleContainerCountChange()

        let frames = try settledFrames(fixture)
        XCTAssertLessThan(frames[1].maxX, monitorFrame.width - sidePadding - 100)
    }

    func testVisibleContainerCountChangeResetsWhenConfigured() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 2)
        fixture.controller.settings.niri.visibleContainerChangeAction = .reset
        fixture.controller.niriLayoutHandler.balanceSizes()
        fixture.controller.settings.niri.visibleContainerCount = 3
        fixture.controller.updateNiriConfig(visibleContainerCount: 3)
        fixture.controller.rebalanceNiriSizesForVisibleContainerCountChange()

        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testResetAfterShrinkToFitSplitsEvenly() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 2)
        try assertResetClearsShrinkToFit(fixture) {
            fixture.controller.niriLayoutHandler.resetLayout()
        }
    }

    func testResetAfterShrinkToFitWithFewerColumnsFills() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 3)
        try assertResetClearsShrinkToFit(fixture) {
            fixture.controller.niriLayoutHandler.resetLayout()
        }
    }

    func testBalanceAfterShrinkToFitSplitsEvenly() throws {
        let fixture = try makeFixture(windowCount: 2, visibleContainerCount: 2)
        try assertResetClearsShrinkToFit(fixture) {
            fixture.controller.niriLayoutHandler.balanceSizes()
        }
    }

    private func assertResetClearsShrinkToFit(_ fixture: Fixture, reset: () -> Void) throws {
        fixture.controller.settings.niri.shrinkToFit = true
        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(70),
            target: .window(fixture.handles[0])
        ))
        let fitted = try settledFrames(fixture)
        XCTAssertGreaterThan(fitted[0].width, fitted[1].width + 100)

        reset()

        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let specs = engine.columns(in: fixture.workspaceId).map(\.width)
        XCTAssertTrue(specs.allSatisfy { $0 == specs[0] })
        XCTAssertTrue(engine.ensureState(for: fixture.workspaceId).shrinkToFitColumnIds.isEmpty)
        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames[0].width, frames[1].width, accuracy: 1)
        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
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
            .appendingPathComponent("OmniWMNiriResetLayoutTests-\(UUID().uuidString)", isDirectory: true)
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
