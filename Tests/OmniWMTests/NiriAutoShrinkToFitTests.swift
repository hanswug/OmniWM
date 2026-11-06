// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import QuartzCore
import XCTest

@MainActor
final class NiriAutoShrinkToFitTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)
    private let sidePadding: CGFloat = 200
    private let innerGap: CGFloat = 10

    func testAWideMinimumMakesTheOthersGiveWay() throws {
        let fixture = try makeEvenFixture(windowCount: 4, visibleContainerCount: 4)
        setMinimumWidth(900, for: fixture.tokens[3], fixture: fixture)
        fixture.controller.settings.niri.shrinkToFitAutomatically = true

        let frames = try settledFrames(fixture)

        XCTAssertGreaterThanOrEqual(frames.map(\.width).max() ?? 0, 900)
        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[3].maxX, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testOffLeavesTheOverflow() throws {
        let fixture = try makeEvenFixture(windowCount: 4, visibleContainerCount: 4)
        setMinimumWidth(900, for: fixture.tokens[3], fixture: fixture)

        let frames = try settledFrames(fixture)

        XCTAssertGreaterThan(frames[3].maxX, monitorFrame.width - sidePadding + 100)
    }

    func testColumnsThatCannotFitMoveOutOfView() throws {
        let fixture = try makeEvenFixture(windowCount: 3, visibleContainerCount: 3)
        for token in fixture.tokens {
            setMinimumWidth(800, for: token, fixture: fixture)
        }
        fixture.controller.settings.niri.shrinkToFitAutomatically = true

        let frames = try settledFrames(fixture)

        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - sidePadding, accuracy: 1)
        XCTAssertGreaterThanOrEqual(frames[2].minX, monitorFrame.width - sidePadding)
    }

    func testResetLayoutHonoursMinimumsWhenAutomaticIsOff() throws {
        let fixture = try makeEvenFixture(windowCount: 4, visibleContainerCount: 4)
        setMinimumWidth(900, for: fixture.tokens[3], fixture: fixture)
        XCTAssertGreaterThan(try settledFrames(fixture)[3].maxX, monitorFrame.width - sidePadding + 100)

        fixture.controller.niriLayoutHandler.resetLayout()

        let frames = try settledFrames(fixture)
        XCTAssertGreaterThanOrEqual(frames.map(\.width).max() ?? 0, 900)
        XCTAssertEqual(frames[0].minX, sidePadding, accuracy: 1)
        XCTAssertEqual(frames[3].maxX, monitorFrame.width - sidePadding, accuracy: 1)
    }

    func testSettingRoundTrips() throws {
        var export = SettingsExport.defaults()
        XCTAssertNil(NiriSettings().export().shrinkToFitAutomatically)
        export.niri.shrinkToFitAutomatically = true
        let decoded = try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export))
        let settings = NiriSettings()
        settings.apply(decoded.niri, baseline: .defaults())
        XCTAssertTrue(settings.shrinkToFitAutomatically)
    }

    private func makeEvenFixture(windowCount: Int, visibleContainerCount: Int) throws -> Fixture {
        let fixture = try makeFixture(windowCount: windowCount, visibleContainerCount: visibleContainerCount)
        for handle in fixture.handles {
            XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
                .setProportion(100 / Double(visibleContainerCount)),
                target: .window(handle)
            ))
        }
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            state.activeColumnIndex = 0
            state.viewOffset = -innerGap
            state.clearOffsetTransition()
        }
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let first = try XCTUnwrap(engine.findNode(for: fixture.tokens[0], in: fixture.workspaceId))
        _ = fixture.controller.workspaceManager.commitWorkspaceSelection(
            nodeId: first.id,
            focusedToken: fixture.tokens[0],
            in: fixture.workspaceId,
            onMonitor: try XCTUnwrap(fixture.controller.workspaceManager.monitor(for: fixture.workspaceId)).id
        )
        _ = try settledFrames(fixture)
        return fixture
    }

    private func setMinimumWidth(_ width: CGFloat, for token: WindowToken, fixture: Fixture) {
        fixture.controller.workspaceManager.setCachedConstraints(
            WindowSizeConstraints(minSize: CGSize(width: width, height: 1), maxSize: .zero, isFixed: false),
            for: token
        )
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
            .appendingPathComponent("OmniWMNiriAutoShrinkToFitTests-\(UUID().uuidString)", isDirectory: true)
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
