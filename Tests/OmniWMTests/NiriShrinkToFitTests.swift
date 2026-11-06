// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import QuartzCore
import XCTest

@MainActor
final class NiriShrinkToFitTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 3840, height: 2160)
    private let sidePadding: CGFloat = 640
    private let innerGap: CGFloat = 9

    private var paddedLeft: CGFloat {
        sidePadding
    }

    private var paddedRight: CGFloat {
        monitorFrame.width - sidePadding
    }

    func testGrowWithoutShrinkToFitPushesTheNeighbourIntoThePadding() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: false)
        grow(fixture, column: 0, steps: 3)

        let frames = try layoutFrames(fixture)
        XCTAssertGreaterThan(frames[1].maxX, paddedRight + 100)
    }

    func testGrowShrinksTheOtherVisibleColumnToFillThePadding() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: true)
        let before = try layoutFrames(fixture)
        grow(fixture, column: 0, steps: 3)

        let frames = try layoutFrames(fixture)
        XCTAssertGreaterThan(frames[0].width, before[0].width + 100)
        XCTAssertLessThan(frames[1].width, before[1].width - 100)
        assertFillsPaddedArea(frames)
    }

    func testRelearnedMinimumRefitsTheVisibleColumns() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: true)
        grow(fixture, column: 0, steps: 6)
        let squeezed = try settledFrames(fixture)
        XCTAssertLessThan(squeezed[1].width, 700)

        var evidence = ObservedSizeEvidence()
        evidence.minSize = CGSize(width: 700, height: 1)
        XCTAssertTrue(fixture.controller.workspaceManager.setObservedSizeEvidence(evidence, for: fixture.tokens[1]))
        fixture.controller.niriLayoutHandler.refitOnScreenColumns(afterMinimumIncreaseOf: fixture.tokens[1])

        let frames = try settledFrames(fixture)
        XCTAssertEqual(frames[1].width, 700, accuracy: 1)
        assertFillsPaddedArea(frames)
    }

    func testRelearnedMinimumIsIgnoredWithoutShrinkToFit() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: false)
        let before = try settledFrames(fixture)
        fixture.controller.niriLayoutHandler.refitOnScreenColumns(afterMinimumIncreaseOf: fixture.tokens[1])
        XCTAssertEqual(try settledFrames(fixture), before)
    }

    func testResizingTheFocusedRightColumnKeepsThePairInsideThePadding() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: true)
        try focusColumn(1, fixture: fixture)
        for change in [NiriSizeChange.adjustProportion(-5), .adjustProportion(-5), .adjustProportion(5)] {
            fixture.controller.niriLayoutHandler.setWindowPrimarySpan(change, target: .focused)
            assertFillsPaddedArea(try settledFrames(fixture))
        }
    }

    func testShrinkGrowsTheOtherVisibleColumnToFillThePadding() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: true)
        let before = try layoutFrames(fixture)
        for _ in 0 ..< 3 {
            fixture.controller.niriLayoutHandler.setWindowPrimarySpan(
                .adjustProportion(-10),
                target: .window(fixture.handles[0])
            )
        }

        let frames = try layoutFrames(fixture)
        XCTAssertLessThan(frames[0].width, before[0].width - 100)
        assertFillsPaddedArea(frames)
    }

    func testNeighbourMinimumCapsTheGrowth() throws {
        let fixture = try makeFixture(windowCount: 2, shrinkToFit: true)
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let neighbour = try XCTUnwrap(engine.findNode(for: fixture.tokens[1], in: fixture.workspaceId))
        neighbour.constraints = WindowSizeConstraints(
            minSize: CGSize(width: 1100, height: 1),
            maxSize: .zero,
            isFixed: false
        )
        grow(fixture, column: 0, steps: 6)

        let frames = try layoutFrames(fixture)
        XCTAssertEqual(frames[1].width, 1100, accuracy: 1)
        assertFillsPaddedArea(frames)
    }

    func testOnlyOnScreenColumnsShareTheSpace() throws {
        let fixture = try makeFixture(windowCount: 3, shrinkToFit: true)
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let columnTokens = engine.columns(in: fixture.workspaceId).compactMap { $0.windowNodes.first?.token }
        XCTAssertEqual(columnTokens.count, 3)
        let offScreenColumn = try XCTUnwrap(engine.columns(in: fixture.workspaceId).last)
        let offScreenWidth = offScreenColumn.settledWidth
        grow(fixture, column: 0, steps: 3)

        let frames = try layoutFrames(fixture)
        let framesByColumn = try columnTokens.map { token in
            try frames[XCTUnwrap(fixture.tokens.firstIndex(of: token))]
        }
        assertFillsPaddedArea(Array(framesByColumn[0 ... 1]))
        XCTAssertEqual(offScreenColumn.settledWidth, offScreenWidth, accuracy: 0.5)
    }

    func testSharesFollowWeightsAndRespectMinimums() {
        XCTAssertEqual(
            NiriLayoutEngine.shrinkToFitShares(remaining: 1000, weights: [300, 100], minimums: [1, 1]),
            [750, 250]
        )
        XCTAssertEqual(
            NiriLayoutEngine.shrinkToFitShares(remaining: 1000, weights: [900, 100], minimums: [1, 400]),
            [600, 400]
        )
    }

    private func assertFillsPaddedArea(_ frames: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(frames.first?.minX ?? 0, paddedLeft, accuracy: 1, file: file, line: line)
        XCTAssertEqual(frames.last?.maxX ?? 0, paddedRight, accuracy: 1, file: file, line: line)
        for (left, right) in zip(frames, frames.dropFirst()) {
            XCTAssertEqual(right.minX - left.maxX, innerGap, accuracy: 1, file: file, line: line)
        }
    }

    private func focusColumn(_ index: Int, fixture: Fixture) throws {
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let node = try XCTUnwrap(engine.findNode(for: fixture.tokens[index], in: fixture.workspaceId))
        _ = fixture.controller.workspaceManager.commitWorkspaceSelection(
            nodeId: node.id,
            focusedToken: fixture.tokens[index],
            in: fixture.workspaceId,
            onMonitor: fixture.controller.workspaceManager.monitorId(for: fixture.workspaceId)
        )
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            let leading = engine.columns(in: fixture.workspaceId).prefix(index)
                .reduce(CGFloat(0)) { $0 + $1.settledWidth + innerGap }
            state.activeColumnIndex = index
            state.viewOffset = -leading - innerGap
            state.clearOffsetTransition()
        }
        _ = try layoutFrames(fixture)
    }

    private func settledFrames(_ fixture: Fixture) throws -> [CGRect] {
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let now = CACurrentMediaTime() + 5
        _ = engine.tickAllColumnAnimations(in: fixture.workspaceId, at: now)
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            state.clearOffsetTransition()
        }
        return try layoutFrames(fixture)
    }

    private func grow(_ fixture: Fixture, column: Int, steps: Int) {
        for _ in 0 ..< steps {
            fixture.controller.niriLayoutHandler.setWindowPrimarySpan(
                .adjustProportion(10),
                target: .window(fixture.handles[column])
            )
        }
    }

    private struct Fixture {
        let controller: WMController
        let workspaceId: WorkspaceDescriptor.ID
        let tokens: [WindowToken]
        let handles: [WindowHandle]
    }

    private func makeFixture(windowCount: Int, shrinkToFit: Bool) throws -> Fixture {
        let settings = makeSettingsStore()
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = Double(innerGap)
        settings.gaps.outerGapLeft = Double(sidePadding)
        settings.gaps.outerGapRight = Double(sidePadding)
        settings.gaps.outerGapTop = 8
        settings.gaps.outerGapBottom = 8
        settings.niri.edgeGaps = false
        settings.niri.shrinkToFit = shrinkToFit
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
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(860 + index)), windowId: 860 + index),
                pid: pid_t(860 + index),
                windowId: 860 + index,
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
            .appendingPathComponent("OmniWMNiriShrinkToFitTests-\(UUID().uuidString)", isDirectory: true)
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
