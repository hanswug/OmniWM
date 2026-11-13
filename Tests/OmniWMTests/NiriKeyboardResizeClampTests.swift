// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import ApplicationServices
import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class NiriKeyboardResizeClampTests: XCTestCase {
    private let monitorFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let outerGap: CGFloat = 120
    private let innerGap: CGFloat = 10

    func testOversizedColumnWidthsStayInsideOuterGaps() throws {
        let changes: [NiriSizeChange] = [.setFixed(5000), .setProportion(300), .adjustFixed(5000)]
        for edgeGaps in [true, false] {
            for change in changes {
                let fixture = try makeFixture(edgeGaps: edgeGaps)
                XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
                    .setProportion(100),
                    target: .window(fixture.handle)
                ))
                let fullWidth = try layoutFrame(fixture).width

                XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
                    change,
                    target: .window(fixture.handle)
                ))
                let frame = try layoutFrame(fixture)

                XCTAssertEqual(frame.width, fullWidth, accuracy: 0.5, "\(change), edgeGaps \(edgeGaps)")
                XCTAssertLessThanOrEqual(
                    frame.width,
                    monitorFrame.width - 2 * outerGap,
                    "\(change), edgeGaps \(edgeGaps)"
                )
            }
        }
    }

    func testRepeatedKeyboardGrowStopsAtOuterGaps() throws {
        let fixture = try makeFixture(edgeGaps: true)
        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(100),
            target: .window(fixture.handle)
        ))
        let fullWidth = try layoutFrame(fixture).width

        for _ in 0 ..< 30 {
            fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
                .adjustProportion(10),
                target: .window(fixture.handle)
            )
        }
        let frame = try layoutFrame(fixture)

        XCTAssertEqual(frame.width, fullWidth, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(frame.minX, outerGap - 0.5)
        XCTAssertLessThanOrEqual(frame.maxX, monitorFrame.width - outerGap + 0.5)
    }

    func testOversizedColumnHeightStaysInsideOuterGapsInVerticalOrientation() throws {
        let fixture = try makeFixture(edgeGaps: true, orientation: .vertical)
        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setProportion(100),
            target: .window(fixture.handle)
        ))
        let fullHeight = try layoutFrame(fixture).height

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setFixed(5000),
            target: .window(fixture.handle)
        ))
        let frame = try layoutFrame(fixture)

        XCTAssertEqual(frame.height, fullHeight, accuracy: 0.5)
        XCTAssertLessThanOrEqual(frame.height, monitorFrame.height - 2 * outerGap)
    }

    func testMinimumWidthStillWinsOverTheViewportCap() throws {
        let fixture = try makeFixture(edgeGaps: true)
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        let node = try XCTUnwrap(engine.findNode(for: fixture.token, in: fixture.workspaceId))
        node.constraints = WindowSizeConstraints(
            minSize: CGSize(width: 1300, height: 1),
            maxSize: .zero,
            isFixed: false
        )

        XCTAssertTrue(fixture.controller.niriLayoutHandler.setContainerPrimarySpan(
            .setFixed(5000),
            target: .window(fixture.handle)
        ))

        XCTAssertEqual(try layoutFrame(fixture).width, 1300, accuracy: 0.5)
    }

    private struct Fixture {
        let controller: WMController
        let workspaceId: WorkspaceDescriptor.ID
        let token: WindowToken
        let handle: WindowHandle
        let tokens: [WindowToken]
    }

    private func makeFixture(
        edgeGaps: Bool,
        orientation: Monitor.Orientation = .horizontal
    ) throws -> Fixture {
        let settings = makeSettingsStore()
        settings.borders.enabled = false
        settings.workspaceBar.enabled = false
        settings.gaps.size = Double(innerGap)
        settings.gaps.outerGapLeft = Double(outerGap)
        settings.gaps.outerGapRight = Double(outerGap)
        settings.gaps.outerGapTop = Double(outerGap)
        settings.gaps.outerGapBottom = Double(outerGap)
        settings.niri.edgeGaps = edgeGaps
        let monitor = Monitor(
            id: .init(displayId: 91),
            displayId: 91,
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
        if orientation == .vertical {
            settings.monitors.orientationOverrides = [
                MonitorOrientationSettings(
                    monitorName: monitor.name,
                    monitorDisplayId: monitor.displayId,
                    orientation: .vertical
                )
            ]
        }
        let controller = WMController(settings: settings)
        controller.setGapSize(innerGap, publishChange: false)
        controller.workspaceManager.applyMonitorConfigurationChange([monitor])
        controller.workspaceManager.applySettings()
        controller.niriLayoutHandler.enableNiriLayout()
        controller.syncMonitorsToNiriEngine()
        let workspaceId = try XCTUnwrap(controller.workspaceManager.workspaceId(named: "1"))
        XCTAssertTrue(controller.workspaceManager.setActiveWorkspace(workspaceId, on: monitor.id))
        let tokens = (0 ..< 2).map { index in
            controller.workspaceManager.addWindow(
                AXWindowRef(element: AXUIElementCreateApplication(pid_t(840 + index)), windowId: 840 + index),
                pid: pid_t(840 + index),
                windowId: 840 + index,
                to: workspaceId
            )
        }
        let fixture = try Fixture(
            controller: controller,
            workspaceId: workspaceId,
            token: tokens[0],
            handle: XCTUnwrap(controller.workspaceManager.handle(for: tokens[0])),
            tokens: tokens
        )
        _ = try layoutFrame(fixture)
        return fixture
    }

    private func layoutFrame(_ fixture: Fixture) throws -> CGRect {
        let plans = fixture.controller.workspaceManager.withBatchedLayoutBuild {
            fixture.controller.niriLayoutHandler.layoutWithNiriEngine(activeWorkspaces: [fixture.workspaceId])
        }
        let plan = try XCTUnwrap(plans.first { $0.workspaceId == fixture.workspaceId })
        if let frame = plan.diff.frameChanges.first(where: { $0.token == fixture.token })?.frame {
            return frame
        }
        let engine = try XCTUnwrap(fixture.controller.niriEngine)
        return try XCTUnwrap(engine.findNode(for: fixture.token, in: fixture.workspaceId)?.renderedFrame)
    }

    private func makeSettingsStore() -> SettingsStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniWMNiriKeyboardResizeClampTests-\(UUID().uuidString)", isDirectory: true)
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
