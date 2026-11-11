// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class NiriPixelEdgeRoundingTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 2400, height: 1200)
    private let padding: CGFloat = 200
    private let gap: CGFloat = 11.5

    func testHalfPointColumnsStayInsideTheWorkingArea() throws {
        let fixture = try makeFixture()
        let frames = try fixture.frames().sorted { $0.minX < $1.minX }

        let scale = try XCTUnwrap(fixture.controller.niriEngine).displayScale(in: fixture.workspaceId)
        let pixels = fixture.columns[0].cachedWidth * scale
        XCTAssertNotEqual(pixels.rounded(), pixels)
        XCTAssertEqual(frames[0].minX, padding)
        XCTAssertEqual(frames[1].minX - frames[0].maxX, gap, accuracy: 1 / scale)
        XCTAssertEqual(frames[1].maxX, monitorFrame.width - padding)
    }

    func testColumnWidthsStayFixedWhileTheViewScrolls() throws {
        let fixture = try makeFixture()
        let scale = try XCTUnwrap(fixture.controller.niriEngine).displayScale(in: fixture.workspaceId)
        let settled = try fixture.frames().map(\.width)

        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            state.viewOffset -= 1 / (4 * scale)
        }

        XCTAssertEqual(try fixture.frames().map(\.width), settled)
    }

    func testAColumnAtAFractionalPositionStartsOnTheWorkingArea() throws {
        let fixture = try makeFixture()
        fixture.tokens.append(fixture.controller.workspaceManager.addWindow(
            AXWindowRef(element: AXUIElementCreateApplication(pid_t(932)), windowId: 932),
            pid: pid_t(932),
            windowId: 932,
            to: fixture.workspaceId
        ))
        _ = try fixture.frames()
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        _ = engine.tickAllColumnAnimations(in: fixture.workspaceId, at: .infinity)
        let scale = engine.displayScale(in: fixture.workspaceId)
        let spans = fixture.columns.map(\.cachedWidth)
        let secondPosition = spans[0] + gap
        XCTAssertNotEqual((secondPosition * scale).rounded(), secondPosition * scale)

        let last = try XCTUnwrap(fixture.columns.last?.windowNodes.first)
        _ = fixture.controller.workspaceManager.commitWorkspaceSelection(
            nodeId: last.id,
            focusedToken: last.token,
            in: fixture.workspaceId,
            onMonitor: try XCTUnwrap(fixture.controller.workspaceManager.monitor(for: fixture.workspaceId)).id
        )
        fixture.controller.workspaceManager.withNiriViewportState(for: fixture.workspaceId) { state in
            state.activeColumnIndex = 2
            state.viewOffset = -(spans[1] + gap) - gap
            state.clearOffsetTransition()
        }

        let frames = try fixture.frames().filter { $0.maxX > padding }.sorted { $0.minX < $1.minX }
        XCTAssertEqual(try XCTUnwrap(frames.first).minX, padding)
        XCTAssertEqual(try XCTUnwrap(frames.last).maxX, monitorFrame.width - padding)
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMNiriPixelEdgeRoundingTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = SettingsStore(
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
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = Double(gap)
        settings.gaps.outerGapLeft = Double(padding)
        settings.gaps.outerGapRight = Double(padding)
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
        controller.motionPolicy.animationsEnabled = false
        controller.setGapSize(gap, publishChange: false)
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.workspaceManager.applySettings()
        controller.niriLayoutHandler.enableNiriLayout()
        controller.syncMonitorsToNiriEngine()
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        let fixture = Fixture(controller: controller, workspaceId: workspaceId)
        for index in 0 ..< 2 {
            fixture.tokens.append(controller.workspaceManager.addWindow(
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(930 + index)), windowId: 930 + index),
                pid: pid_t(930 + index),
                windowId: 930 + index,
                to: workspaceId
            ))
            _ = try fixture.frames()
        }
        let engine = try XCTUnwrap(controller.niriEngine)
        let first = try XCTUnwrap(engine.findNode(for: fixture.tokens[0], in: workspaceId))
        _ = controller.workspaceManager.commitWorkspaceSelection(
            nodeId: first.id,
            focusedToken: fixture.tokens[0],
            in: workspaceId,
            onMonitor: monitor.id
        )
        controller.workspaceManager.withNiriViewportState(for: workspaceId) { state in
            state.activeColumnIndex = 0
            state.viewOffset = -gap
            state.clearOffsetTransition()
        }
        _ = engine.tickAllColumnAnimations(in: workspaceId, at: .infinity)
        _ = controller.workspaceManager.animationDriver.tick(in: workspaceId, at: .infinity)
        return fixture
    }
}

@MainActor
private final class Fixture {
    let controller: WMController
    let workspaceId: WorkspaceDescriptor.ID
    var tokens: [WindowToken] = []

    init(controller: WMController, workspaceId: WorkspaceDescriptor.ID) {
        self.controller = controller
        self.workspaceId = workspaceId
    }

    var columns: [NiriContainer] {
        controller.niriEngine?.columns(in: workspaceId) ?? []
    }

    func frames() throws -> [CGRect] {
        let plans = controller.workspaceManager.withBatchedLayoutBuild {
            controller.niriLayoutHandler.layoutWithNiriEngine(activeWorkspaces: [workspaceId])
        }
        let plan = try XCTUnwrap(plans.first { $0.workspaceId == workspaceId })
        let engine = try XCTUnwrap(controller.niriEngine)
        return try tokens.map { token in
            if let frame = plan.diff.frameChanges.first(where: { $0.token == token })?.frame {
                return frame
            }
            return try XCTUnwrap(engine.findNode(for: token, in: workspaceId)?.renderedFrame)
        }
    }
}
